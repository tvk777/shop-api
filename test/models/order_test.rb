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

  test "place! rejects a quantity outside 1..99 with a clean message and saves nothing" do
    [ 0, 100 ].each do |quantity|
      assert_no_difference [ "Order.count", "OrderDescription.count" ] do
        error = assert_raises(Order::InvalidOrder) do
          Order.place!(user: @user, lines: [ { item_id: @coffee.id, quantity: quantity } ])
        end
        assert_equal "Quantity must be between 1 and 99", error.message
      end
    end
  end

  test "place! rejects the same item on more than one line and saves nothing" do
    assert_no_difference [ "Order.count", "OrderDescription.count" ] do
      error = assert_raises(Order::InvalidOrder) do
        Order.place!(user: @user, lines: [
          { item_id: @coffee.id, quantity: 60 },
          { item_id: @coffee.id.to_s, quantity: "60" }
        ])
      end
      assert_equal "Each item can appear only once in an order", error.message
    end
  end

  test "place! reports an item deleted during checkout as not found" do
    doomed = Item.create!(name: "Discontinued", price: 1)
    deleted = false
    # Deletes the item right after place! has loaded it and before the save transaction starts,
    # like a concurrent admin delete, so the real foreign key check fails on insert.
    delete_item = lambda do |event|
      next if deleted || event.payload[:name] != "Item Load"

      deleted = true
      Item.where(id: doomed.id).delete_all
    end

    assert_no_difference [ "Order.count", "OrderDescription.count" ] do
      error = assert_raises(Order::InvalidOrder) do
        ActiveSupport::Notifications.subscribed(delete_item, "sql.active_record") do
          Order.place!(user: @user, lines: [
            { item_id: @coffee.id, quantity: 1 },
            { item_id: doomed.id, quantity: 1 }
          ])
        end
      end
      assert_equal "Items not found: #{doomed.id}", error.message
    end
    assert deleted, "the item was not deleted during checkout"
  end

  test "place! accepts a quantity of 99" do
    order = Order.place!(user: @user, lines: [ { item_id: @coffee.id, quantity: 99 } ])

    assert_equal 99, order.order_descriptions.first.quantity
  end

  test "place! rejects a total above the amount column maximum and saves nothing" do
    expensive = Item.create!(name: "Rare beans", price: Item::MAX_PRICE)

    assert_no_difference [ "Order.count", "OrderDescription.count" ] do
      error = assert_raises(Order::InvalidOrder) do
        Order.place!(user: @user, lines: [ { item_id: expensive.id, quantity: 2 } ])
      end
      assert_equal "Order total is too large", error.message
    end
  end

  test "amount above the maximum is invalid" do
    order = Order.new(user: @user, amount: Order::MAX_AMOUNT + BigDecimal("0.01"))

    assert_not order.valid?
    assert order.errors.of_kind?(:amount, :less_than_or_equal_to)
  end

  test "place! rejects non-integer item_id and quantity and saves nothing" do
    [ "2.7", 2.7, "12junk", "", nil, "-1", " 2", [ 1 ], { a: 1 } ].each do |bad|
      [ :item_id, :quantity ].each do |field|
        line = { item_id: @coffee.id, quantity: 1 }.merge(field => bad)

        assert_no_difference [ "Order.count", "OrderDescription.count" ] do
          assert_raises(Order::InvalidOrder, "expected InvalidOrder for #{field}=#{bad.inspect}") do
            Order.place!(user: @user, lines: [ line ])
          end
        end
      end
    end
  end

  test "place! accepts digit strings" do
    order = Order.place!(user: @user, lines: [ { item_id: @coffee.id.to_s, quantity: "2" } ])

    assert_equal 2, order.order_descriptions.first.quantity
  end
end
