ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Each test starts with a fresh login rate limit (every request comes from 127.0.0.1).
    setup { Users::SessionsController::LOGIN_RATE_LIMIT_STORE.clear }

    def auth_headers_for(user, password: "password123")
      post user_session_path, params: { user: { email: user.email, password: password } }, as: :json
      { "Authorization" => response.headers["Authorization"] }
    end
  end
end
