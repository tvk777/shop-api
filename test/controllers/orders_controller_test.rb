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

  test "an admin cannot list, view or place orders" do
    headers = auth_headers_for(users(:admin))
    forbidden = { "errors" => [ "Admins cannot place or view orders" ] }

    get orders_path, headers: headers
    assert_response :forbidden
    assert_equal forbidden, response.parsed_body

    get order_path(@bobs_order), headers: headers
    assert_response :forbidden
    assert_equal forbidden, response.parsed_body

    assert_no_difference [ "Order.count", "OrderDescription.count" ] do
      post orders_path, params: { order: { items: [ { item_id: items(:coffee).id, quantity: 1 } ] } },
                        headers: headers, as: :json
    end
    assert_response :forbidden
    assert_equal forbidden, response.parsed_body
  end

  test "lists only your own orders, newest first" do
    newer = Order.place!(user: @alice, lines: [ { item_id: items(:coffee).id, quantity: 1 } ])
    older = Order.place!(user: @alice, lines: [ { item_id: items(:tea).id, quantity: 1 } ])
    older.update_columns(created_at: 1.day.ago)

    get orders_path, headers: auth_headers_for(@alice)

    assert_response :ok
    assert_equal [ newer.id, older.id ], response.parsed_body["data"].map { |order| order["id"] }
  end

  test "the same item on more than one line returns 422 and saves nothing" do
    lines = [ { item_id: items(:coffee).id, quantity: 60 }, { item_id: items(:coffee).id, quantity: 60 } ]

    assert_no_difference [ "Order.count", "OrderDescription.count" ] do
      post orders_path, params: { order: { items: lines } }, headers: auth_headers_for(@alice), as: :json
    end
    assert_response :unprocessable_entity
    assert_equal [ "Each item can appear only once in an order" ], response.parsed_body["errors"]
  end

  test "a quantity outside 1..99 returns a clean message" do
    headers = auth_headers_for(@alice)

    [ 0, 100 ].each do |quantity|
      post orders_path, params: { order: { items: [ { item_id: items(:coffee).id, quantity: quantity } ] } },
                        headers: headers, as: :json
      assert_response :unprocessable_entity
      assert_equal [ "Quantity must be between 1 and 99" ], response.parsed_body["errors"]
    end
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

  test "malformed order params return 400" do
    headers = auth_headers_for(@alice)

    [ { order: "abc" }, { order: { items: "abc" } } ].each do |payload|
      post orders_path, params: payload, headers: headers, as: :json
      assert_response :bad_request, "expected 400 for #{payload.inspect}"
    end
  end

  test "order JSON keeps its shape" do
    get order_path(@bobs_order), headers: auth_headers_for(@bob)

    body = response.parsed_body
    assert_equal %w[amount created_at id items], body.keys.sort
    assert_equal %w[item_id name price quantity], body["items"].first.keys.sort
  end

  test "malformed item_id or quantity returns 422 and saves nothing" do
    headers = auth_headers_for(@alice)

    [ "2.7", 2.7, "12junk", "", nil, [ 1 ], -1, "-1" ].each do |bad|
      [ :item_id, :quantity ].each do |field|
        line = { item_id: items(:coffee).id, quantity: 1 }.merge(field => bad)

        assert_no_difference [ "Order.count", "OrderDescription.count" ] do
          post orders_path, params: { order: { items: [ line ] } }, headers: headers, as: :json
        end
        assert_response :unprocessable_entity, "expected 422 for #{field}=#{bad.inspect}"
        assert response.parsed_body["errors"].present?
      end
    end
  end

  test "a very large item_id returns 422" do
    post orders_path, params: { order: { items: [ { item_id: "9" * 30, quantity: 1 } ] } },
                      headers: auth_headers_for(@alice), as: :json

    assert_response :unprocessable_entity
  end

  test "places an order with numeric and digit-string values" do
    headers = auth_headers_for(@alice)

    [ { item_id: items(:coffee).id, quantity: 2 }, { item_id: items(:coffee).id.to_s, quantity: "2" } ].each do |line|
      assert_difference [ "Order.count", "OrderDescription.count" ], 1 do
        post orders_path, params: { order: { items: [ line ] } }, headers: headers, as: :json
      end
      assert_response :created
      assert_equal 2, response.parsed_body["items"].first["quantity"]
    end
  end

  test "paginates your own orders newest first with the default per_page of 10" do
    orders = 11.times.map do |i|
      order = Order.place!(user: @alice, lines: [ { item_id: items(:coffee).id, quantity: 1 } ])
      order.update_columns(created_at: i.hours.ago)
      order
    end
    headers = auth_headers_for(@alice)

    get orders_path, headers: headers
    assert_response :ok
    first_page = response.parsed_body["data"].map { |order| order["id"] }
    assert_equal({ "page" => 1, "per_page" => 10, "total" => 11, "total_pages" => 2 }, response.parsed_body["meta"])

    get orders_path, params: { page: 2 }, headers: headers
    assert_response :ok
    second_page = response.parsed_body["data"].map { |order| order["id"] }
    assert_equal({ "page" => 2, "per_page" => 10, "total" => 11, "total_pages" => 2 }, response.parsed_body["meta"])

    assert_equal orders.map(&:id), first_page + second_page
    assert_not_includes first_page + second_page, @bobs_order.id

    get orders_path, params: { page: 3 }, headers: headers
    assert_response :ok
    assert_equal [], response.parsed_body["data"]
    assert_equal({ "page" => 3, "per_page" => 10, "total" => 11, "total_pages" => 2 }, response.parsed_body["meta"])
  end

  test "paginated orders keep their lines" do
    get orders_path, params: { per_page: 1 }, headers: auth_headers_for(@bob)

    assert_response :ok
    order = response.parsed_body["data"].first
    assert_equal %w[amount created_at id items], order.keys.sort
    assert_equal [ { "item_id" => items(:coffee).id, "name" => "Espresso", "price" => "3.5", "quantity" => 1 } ], order["items"]
  end

  test "invalid orders pagination returns 400" do
    get orders_path, params: { per_page: 51 }, headers: auth_headers_for(@alice)

    assert_response :bad_request
    assert_equal({ "errors" => [ "Invalid pagination parameters" ] }, response.parsed_body)
  end

  test "an admin still gets 403 on orders with pagination params" do
    get orders_path, params: { page: 2, per_page: 5 }, headers: auth_headers_for(users(:admin))

    assert_response :forbidden
    assert_equal({ "errors" => [ "Admins cannot place or view orders" ] }, response.parsed_body)
  end
end
