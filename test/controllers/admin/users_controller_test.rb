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
end
