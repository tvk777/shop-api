require "test_helper"

class OrderTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
    @coffee = items(:coffee)
    @tea = items(:tea)
  end

  test "place! computes total and stores unit_price" do
    order = Order.place!(user: @user, lines: [
      { item_id: @coffee.id, quantity: 2 },
      { item_id: @tea.id, quantity: 1 }
    ])

    assert_equal BigDecimal("9.25"), order.amount
    assert_equal [ BigDecimal("3.5"), BigDecimal("2.25") ], order.order_descriptions.order(:id).map(&:unit_price)
  end

  test "place! keeps historical unit_price when item price changes" do
    order = Order.place!(user: @user, lines: [ { item_id: @coffee.id, quantity: 1 } ])
    @coffee.update!(price: 10)

    assert_equal BigDecimal("3.5"), order.order_descriptions.first.unit_price
  end

  test "place! rejects empty and unknown items" do
    assert_raises(Order::InvalidOrder) { Order.place!(user: @user, lines: []) }
    assert_raises(Order::InvalidOrder) do
      Order.place!(user: @user, lines: [ { item_id: 0, quantity: 1 } ])
    end
  end

  test "place! saves nothing when one line is invalid" do
    assert_no_difference [ "Order.count", "OrderDescription.count" ] do
      assert_raises(Order::InvalidOrder) do
        Order.place!(user: @user, lines: [
          { item_id: @coffee.id, quantity: 1 },
          { item_id: @tea.id, quantity: -1 }
        ])
      end
    end
  end
end
