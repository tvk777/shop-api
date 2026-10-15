require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "as_json exposes only public attributes" do
    json = users(:alice).as_json

    assert_equal %w[email first_name id last_name role], json.keys.sort
    assert_not json.key?("encrypted_password")
    assert_not json.key?("jti")
  end

  # Over HTTP this cannot happen serially (self-delete is rejected first), so the guard is tested here.
  test "the last admin cannot be deleted" do
    admin = users(:admin)
    Order.place!(user: users(:bob), lines: [ { item_id: items(:coffee).id, quantity: 1 } ])

    assert_no_difference [ "User.count", "Order.count", "OrderDescription.count" ] do
      assert_not admin.destroy
    end
    assert_equal [ "At least one admin is required" ], admin.errors.full_messages
  end

  test "an admin can be deleted while another admin remains" do
    users(:bob).update!(role: :admin)

    assert_difference "User.count", -1 do
      assert users(:admin).destroy
    end
  end
end
