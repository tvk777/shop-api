require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @bobs_order = Order.place!(user: @bob, lines: [ { item_id: items(:coffee).id, quantity: 1 } ])
  end

  test "requires a token" do
    get orders_path
    assert_response :unauthorized
  end

  test "returns 404 for another user's order" do
    get order_path(@bobs_order), headers: auth_headers_for(@alice)
    assert_response :not_found
  end

  test "returns your own order" do
    get order_path(@bobs_order), headers: auth_headers_for(@bob)
    assert_response :ok
    assert_equal @bobs_order.id, response.parsed_body["id"]
  end
end
