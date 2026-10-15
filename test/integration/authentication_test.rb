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

  test "signup with invalid input returns 422 and creates no user" do
    invalid = { first_name: "", last_name: "", email: "not-an-email", password: "123", password_confirmation: "123" }

    assert_no_difference "User.count" do
      post user_registration_path, params: { user: invalid }, as: :json
    end
    assert_response :unprocessable_entity
    assert_nil response.headers["Authorization"]
    errors = response.parsed_body["errors"]
    [ "First name can't be blank", "Last name can't be blank", "Email is invalid",
      "Password is too short (minimum is 6 characters)" ].each do |message|
      assert_includes errors, message
    end
  end

  test "signup with a taken email returns 422" do
    [ users(:alice).email, users(:alice).email.upcase ].each do |email|
      assert_no_difference "User.count" do
        post user_registration_path, params: { user: SIGNUP.merge(email: email) }, as: :json
      end
      assert_response :unprocessable_entity
      assert_includes response.parsed_body["errors"], "Email has already been taken"
    end
  end

  test "login is rate limited per IP and email" do
    alice = users(:alice).email
    10.times do |attempt|
      # Case and spaces do not create a separate limit.
      email = attempt.even? ? alice : " #{alice.upcase} "
      post user_session_path, params: { user: { email: email, password: "wrong" } }, as: :json
      assert_response :unauthorized
    end

    post user_session_path, params: { user: { email: alice, password: "password123" } }, as: :json
    assert_response :too_many_requests
    assert_equal({ "errors" => [ "Too many login attempts. Try again later." ] }, response.parsed_body)
    assert_nil response.headers["Authorization"]

    post user_session_path, params: { user: { email: users(:bob).email, password: "password123" } }, as: :json
    assert_response :ok

    post user_session_path, params: { user: { email: alice, password: "password123" } },
                            env: { "REMOTE_ADDR" => "203.0.113.5" }, as: :json
    assert_response :ok
  end

  test "login with a non-hash user param does not crash the rate limit" do
    post user_session_path, params: { user: "abc" }, as: :json
    assert_operator response.status, :<, 500
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
