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

  test "login with a wrong password returns 401 and no token" do
    post user_session_path, params: { user: { email: users(:alice).email, password: "wrong" } }, as: :json

    assert_response :unauthorized
    assert_nil response.headers["Authorization"]
  end

  test "a token is rejected after logout" do
    headers = auth_headers_for(users(:alice))

    delete destroy_user_session_path, headers: headers
    assert_response :no_content

    get items_path, headers: headers
    assert_response :unauthorized
  end

  test "an invalid or malformed token is rejected" do
    token = auth_headers_for(users(:alice))["Authorization"]
    tampered = "#{token[0..-3]}#{token[-2..].reverse}"
    tampered = "#{token[0..-2]}x" if tampered == token

    [ "Bearer garbage", "Bearer", "garbage", tampered ].each do |value|
      get items_path, headers: { "Authorization" => value }
      assert_response :unauthorized, "expected 401 for #{value.inspect}"
    end
  end

  test "login does not leave a session cookie that authenticates on its own" do
    post user_session_path, params: { user: { email: users(:alice).email, password: "password123" } }, as: :json
    assert_response :ok

    get items_path
    assert_response :unauthorized
  end

  test "signup does not leave a session cookie that authenticates on its own" do
    post user_registration_path, params: { user: SIGNUP }, as: :json
    assert_response :created

    get items_path
    assert_response :unauthorized
  end
end
