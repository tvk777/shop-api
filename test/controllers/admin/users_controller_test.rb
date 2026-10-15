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
    assert_equal User.count, response.parsed_body.size
    assert response.parsed_body.none? { |u| u.key?("encrypted_password") || u.key?("jti") }

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
    counts = response.parsed_body.to_h { |u| [ u["email"], u["orders_count"] ] }
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

  private

  # Two orders with three lines in total.
  def place_orders_for(user)
    Order.place!(user: user, lines: [ { item_id: items(:coffee).id, quantity: 1 } ])
    Order.place!(user: user, lines: [ { item_id: items(:coffee).id, quantity: 2 }, { item_id: items(:coffee).id, quantity: 1 } ])
  end
end
