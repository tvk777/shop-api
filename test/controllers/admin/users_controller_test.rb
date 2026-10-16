require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "requires a token" do
    get admin_users_path
    assert_response :unauthorized
  end

  test "forbids a regular user" do
    headers = auth_headers_for(users(:alice))

    get admin_users_path, headers: headers
    assert_response :forbidden
    assert_equal [ "Forbidden" ], response.parsed_body["errors"]

    patch admin_user_path(users(:bob)), params: { user: { first_name: "X" } }, headers: headers, as: :json
    assert_response :forbidden
  end

  test "admin lists and shows users without secrets" do
    headers = auth_headers_for(users(:admin))

    get admin_users_path, headers: headers
    assert_response :ok
    assert_equal User.count, response.parsed_body["data"].size
    assert response.parsed_body["data"].none? { |u| u.key?("encrypted_password") || u.key?("jti") }

    get admin_user_path(users(:bob)), headers: headers
    assert_response :ok
    assert_equal "bob@example.com", response.parsed_body["email"]
  end

  test "admin changes a user's role" do
    patch admin_user_path(users(:bob)), params: { user: { role: "admin" } },
                                        headers: auth_headers_for(users(:admin)), as: :json

    assert_response :ok
    assert_equal "admin", users(:bob).reload.role
  end

  test "invalid role returns 422" do
    patch admin_user_path(users(:bob)), params: { user: { role: "superuser" } },
                                        headers: auth_headers_for(users(:admin)), as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["errors"].present?
    assert_equal "user", users(:bob).reload.role
  end

  test "admin cannot demote themselves" do
    admin = users(:admin)
    patch admin_user_path(admin), params: { user: { role: "user" } },
                                  headers: auth_headers_for(admin), as: :json

    assert_response :unprocessable_entity
    assert_equal "admin", admin.reload.role
  end

  test "returns 404 for a missing user" do
    get admin_user_path(id: 0), headers: auth_headers_for(users(:admin))
    assert_response :not_found
  end

  test "deleting a user removes their orders and order lines but no items" do
    bob = users(:bob)
    place_orders_for(bob)
    headers = auth_headers_for(users(:admin))

    assert_difference({ "User.count" => -1, "Order.count" => -2, "OrderDescription.count" => -3 }) do
      assert_no_difference "Item.count" do
        delete admin_user_path(bob), headers: headers
      end
    end

    assert_response :no_content
    assert_not User.exists?(bob.id)
    assert_not Order.exists?(user_id: bob.id)
  end

  test "deleting a user without orders works" do
    alice = users(:alice)

    assert_difference "User.count", -1 do
      delete admin_user_path(alice), headers: auth_headers_for(users(:admin))
    end

    assert_response :no_content
    assert_not User.exists?(alice.id)
  end

  test "an admin cannot delete their own account" do
    admin = users(:admin)
    place_orders_for(users(:bob))

    assert_no_difference [ "User.count", "Order.count", "OrderDescription.count" ] do
      delete admin_user_path(admin), headers: auth_headers_for(admin)
    end

    assert_response :unprocessable_entity
    assert_equal [ "You cannot delete your own account" ], response.parsed_body["errors"]
  end

  test "deleting a missing user returns 404" do
    delete admin_user_path(id: 0), headers: auth_headers_for(users(:admin))
    assert_response :not_found
  end

  test "a regular user cannot delete users" do
    assert_no_difference "User.count" do
      delete admin_user_path(users(:bob)), headers: auth_headers_for(users(:alice))
    end

    assert_response :forbidden
  end

  test "a deleted user's token is rejected" do
    bob = users(:bob)
    bob_headers = auth_headers_for(bob)

    delete admin_user_path(bob), headers: auth_headers_for(users(:admin))
    assert_response :no_content

    get profile_path, headers: bob_headers
    assert_response :unauthorized
  end

  test "admin responses include orders_count" do
    bob = users(:bob)
    place_orders_for(bob)
    headers = auth_headers_for(users(:admin))

    get admin_users_path, headers: headers
    assert_response :ok
    counts = response.parsed_body["data"].to_h { |u| [ u["email"], u["orders_count"] ] }
    assert_equal({ "alice@example.com" => 0, "bob@example.com" => 2, "admin@example.com" => 0 }, counts)

    get admin_user_path(bob), headers: headers
    assert_response :ok
    assert_equal 2, response.parsed_body["orders_count"]
  end

  test "login and profile responses do not include orders_count" do
    alice = users(:alice)
    place_orders_for(alice)

    headers = auth_headers_for(alice)
    assert_not response.parsed_body["user"].key?("orders_count")

    get profile_path, headers: headers
    assert_response :ok
    assert_not response.parsed_body.key?("orders_count")
  end

  test "admin users are paginated by id with the default per_page of 20" do
    18.times do |i|
      User.create!(email: "user#{i}@example.com", password: "password123", first_name: "U", last_name: "Ser")
    end
    last_user = User.order(:id).last
    place_orders_for(last_user)
    headers = auth_headers_for(users(:admin))

    get admin_users_path, headers: headers
    assert_response :ok
    assert_equal User.order(:id).limit(20).ids, response.parsed_body["data"].map { |u| u["id"] }
    assert_equal({ "page" => 1, "per_page" => 20, "total" => 21, "total_pages" => 2 }, response.parsed_body["meta"])
    assert_kind_of Integer, response.parsed_body["meta"]["total"]

    get admin_users_path, params: { page: 2 }, headers: headers
    assert_response :ok
    assert_equal [ { "id" => last_user.id, "email" => last_user.email, "first_name" => "U", "last_name" => "Ser",
                     "role" => "user", "orders_count" => 2 } ], response.parsed_body["data"]
    assert_equal({ "page" => 2, "per_page" => 20, "total" => 21, "total_pages" => 2 }, response.parsed_body["meta"])

    get admin_users_path, params: { page: 3 }, headers: headers
    assert_response :ok
    assert_equal [], response.parsed_body["data"]
    assert_equal({ "page" => 3, "per_page" => 20, "total" => 21, "total_pages" => 2 }, response.parsed_body["meta"])

    get admin_users_path, params: { per_page: 51 }, headers: headers
    assert_response :bad_request
    assert_equal({ "errors" => [ "Invalid pagination parameters" ] }, response.parsed_body)
  end

  test "orders_count is correct on a later page with a small per_page" do
    bob = users(:bob)
    place_orders_for(bob)
    position = User.order(:id).ids.index(bob.id)

    get admin_users_path, params: { page: position + 1, per_page: 1 }, headers: auth_headers_for(users(:admin))

    assert_response :ok
    assert_equal [ [ bob.id, 2 ] ], response.parsed_body["data"].map { |u| [ u["id"], u["orders_count"] ] }
    assert_equal({ "page" => position + 1, "per_page" => 1, "total" => 3, "total_pages" => 3 }, response.parsed_body["meta"])
  end

  test "a regular user still gets 403 on the admin user list with pagination params" do
    get admin_users_path, params: { page: 2, per_page: 5 }, headers: auth_headers_for(users(:alice))

    assert_response :forbidden
    assert_equal [ "Forbidden" ], response.parsed_body["errors"]
  end

  private

  # Two orders with three lines in total.
  def place_orders_for(user)
    Order.place!(user: user, lines: [ { item_id: items(:coffee).id, quantity: 1 } ])
    Order.place!(user: user, lines: [ { item_id: items(:coffee).id, quantity: 2 }, { item_id: items(:tea).id, quantity: 1 } ])
  end
end
