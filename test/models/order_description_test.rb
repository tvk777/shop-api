require "test_helper"

class OrderDescriptionTest < ActiveSupport::TestCase
  test "database rejects a quantity above the maximum" do
    order = Order.place!(user: users(:alice), lines: [ { item_id: items(:coffee).id, quantity: 1 } ])

    assert_raises(ActiveRecord::StatementInvalid) do
      order.order_descriptions.first.update_columns(quantity: OrderDescription::MAX_QUANTITY + 1)
    end
  end
end
