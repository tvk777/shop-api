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
    assert_nil response.headers["Authorization"]
    assert_equal "jti-alice", @alice.jti
  end

  test "password change revokes old tokens and returns a new one" do
    old_headers = auth_headers_for(@alice)

    patch profile_path, params: { user: { password: "newpass123", password_confirmation: "newpass123",
                                          current_password: "password123" } },
                        headers: old_headers, as: :json

    assert_response :ok
    assert_equal "alice@example.com", response.parsed_body["email"]
    new_token = response.headers["Authorization"]
    assert new_token.to_s.start_with?("Bearer ")
    assert_not_equal "jti-alice", @alice.reload.jti

    get profile_path, headers: old_headers
    assert_response :unauthorized

    get profile_path, headers: { "Authorization" => new_token }
    assert_response :ok
  end

  test "password change with a wrong current password keeps the jti and the old token" do
    headers = auth_headers_for(@alice)

    patch profile_path, params: { user: { password: "newpass123", password_confirmation: "newpass123",
                                          current_password: "wrong" } },
                        headers: headers, as: :json

    assert_response :unprocessable_entity
    assert_nil response.headers["Authorization"]
    assert_equal "jti-alice", @alice.reload.jti

    get profile_path, headers: headers
    assert_response :ok
  end

  test "email change requires the current password" do
    headers = auth_headers_for(@alice)

    patch profile_path, params: { user: { email: "alice.new@example.com" } }, headers: headers, as: :json
    assert_response :unprocessable_entity
    assert_equal [ "Current password is required to change your email" ], response.parsed_body["errors"]
    assert_equal "alice@example.com", @alice.reload.email

    patch profile_path, params: { user: { email: "alice.new@example.com", current_password: "wrong" } },
                        headers: headers, as: :json
    assert_response :unprocessable_entity
    assert_equal [ "Current password is invalid" ], response.parsed_body["errors"]
    assert_equal "alice@example.com", @alice.reload.email

    patch profile_path, params: { user: { email: "alice.new@example.com", current_password: "password123" } },
                        headers: headers, as: :json
    assert_response :ok
    assert_equal "alice.new@example.com", response.parsed_body["email"]
    assert_equal "alice.new@example.com", @alice.reload.email
    assert_nil response.headers["Authorization"]
    assert_equal "jti-alice", @alice.jti
  end

  test "the same email in another case is not a change" do
    patch profile_path, params: { user: { email: "  ALICE@Example.com " } }, headers: auth_headers_for(@alice), as: :json

    assert_response :ok
    assert_equal "alice@example.com", @alice.reload.email
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
