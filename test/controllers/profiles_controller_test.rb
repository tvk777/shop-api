require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
  end

  test "requires a token" do
    get profile_path
    assert_response :unauthorized

    patch profile_path, params: { user: { first_name: "X" } }, as: :json
    assert_response :unauthorized
  end

  test "shows the current user" do
    get profile_path, headers: auth_headers_for(@alice)

    assert_response :ok
    assert_equal "alice@example.com", response.parsed_body["email"]
    assert_not response.parsed_body.key?("jti")
  end

  test "updates own name" do
    patch profile_path, params: { user: { first_name: "Alicia" } }, headers: auth_headers_for(@alice), as: :json

    assert_response :ok
    assert_equal "Alicia", response.parsed_body["first_name"]
    assert_equal "Alicia", @alice.reload.first_name
  end

  test "ignores a role param" do
    patch profile_path, params: { user: { first_name: "Alicia", role: "admin" } }, headers: auth_headers_for(@alice), as: :json

    assert_response :ok
    assert_equal "user", @alice.reload.role
  end

  test "password change needs the correct current_password" do
    patch profile_path, params: { user: { password: "newpass123", password_confirmation: "newpass123" } },
                        headers: auth_headers_for(@alice), as: :json
    assert_response :unprocessable_entity
    assert @alice.reload.valid_password?("password123")

    patch profile_path, params: { user: { password: "newpass123", password_confirmation: "newpass123",
                                          current_password: "wrong" } },
                        headers: auth_headers_for(@alice), as: :json
    assert_response :unprocessable_entity

    patch profile_path, params: { user: { password: "newpass123", password_confirmation: "newpass123",
                                          current_password: "password123" } },
                        headers: auth_headers_for(@alice), as: :json
    assert_response :ok
    assert @alice.reload.valid_password?("newpass123")
  end

  test "duplicate email returns 422" do
    patch profile_path, params: { user: { email: users(:bob).email } }, headers: auth_headers_for(@alice), as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["errors"].present?
  end
end
