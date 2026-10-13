require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  test "GET /up works without a token" do
    get rails_health_check_path

    assert_response :success
  end
end
