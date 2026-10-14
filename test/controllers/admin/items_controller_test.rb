require "test_helper"

class Admin::ItemsControllerTest < ActionDispatch::IntegrationTest
  test "requires a token" do
    get admin_items_path
    assert_response :unauthorized
  end

  test "forbids a regular user" do
    headers = auth_headers_for(users(:alice))

    get admin_items_path, headers: headers
    assert_response :forbidden

    post admin_items_path, params: { item: { name: "X", price: 1 } }, headers: headers, as: :json
    assert_response :forbidden

    delete admin_item_path(items(:tea)), headers: headers
    assert_response :forbidden
  end

  test "admin lists and shows items" do
    headers = auth_headers_for(users(:admin))

    get admin_items_path, headers: headers
    assert_response :ok
    assert_equal Item.count, response.parsed_body.size

    get admin_item_path(items(:tea)), headers: headers
    assert_response :ok
    assert_equal "Green tea", response.parsed_body["name"]
  end

  test "admin creates an item" do
    assert_difference "Item.count", 1 do
      post admin_items_path, params: { item: { name: "Mocha", description: "Chocolate coffee", price: 4.2 } },
                             headers: auth_headers_for(users(:admin)), as: :json
    end

    assert_response :created
    assert_equal "Mocha", response.parsed_body["name"]
  end

  test "price above the column maximum returns 422" do
    assert_no_difference "Item.count" do
      post admin_items_path, params: { item: { name: "Too much", price: 1_000_000_000 } },
                             headers: auth_headers_for(users(:admin)), as: :json
    end

    assert_response :unprocessable_entity
    assert_kind_of Array, response.parsed_body["errors"]
  end

  test "invalid item returns 422" do
    assert_no_difference "Item.count" do
      post admin_items_path, params: { item: { name: "", price: -1 } },
                             headers: auth_headers_for(users(:admin)), as: :json
    end

    assert_response :unprocessable_entity
    assert response.parsed_body["errors"].present?
  end

  test "admin updates an item" do
    patch admin_item_path(items(:tea)), params: { item: { price: 9.99 } },
                                        headers: auth_headers_for(users(:admin)), as: :json

    assert_response :ok
    assert_equal 9.99, items(:tea).reload.price.to_f
  end

  test "admin destroys an unused item" do
    assert_difference "Item.count", -1 do
      delete admin_item_path(items(:tea)), headers: auth_headers_for(users(:admin))
    end

    assert_response :no_content
  end

  test "destroying an item used in an order returns 422 and keeps the item" do
    Order.place!(user: users(:bob), lines: [ { item_id: items(:coffee).id, quantity: 1 } ])

    assert_no_difference "Item.count" do
      delete admin_item_path(items(:coffee)), headers: auth_headers_for(users(:admin))
    end

    assert_response :unprocessable_entity
    assert response.parsed_body["errors"].present?
  end

  test "admin search rejects a non-string q and accepts a missing or blank one" do
    headers = auth_headers_for(users(:admin))

    get "#{admin_items_path}?q[]=x", headers: headers
    assert_response :bad_request
    assert_equal({ "errors" => [ "Invalid search parameter" ] }, response.parsed_body)

    [ {}, { q: "" } ].each do |params|
      get admin_items_path, params: params, headers: headers
      assert_response :ok
      assert_equal Item.count, response.parsed_body.size
    end
  end
end
