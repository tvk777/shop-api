require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  SIGNUP = { first_name: "Carol", last_name: "Clark", email: "carol@example.com",
             password: "password123", password_confirmation: "password123" }.freeze

  test "signup returns a JWT and ignores a client-sent role" do
    post user_registration_path, params: { user: SIGNUP.merge(role: "admin") }, as: :json

    assert_response :created
    assert response.headers["Authorization"].to_s.start_with?("Bearer ")
    assert_equal "user", User.find_by!(email: "carol@example.com").role
  end

  test "login returns a JWT" do
    post user_session_path, params: { user: { email: users(:alice).email, password: "password123" } }, as: :json

    assert_response :ok
    assert response.headers["Authorization"].to_s.start_with?("Bearer ")
  end
end
