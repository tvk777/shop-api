require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "as_json exposes only public attributes" do
    json = users(:alice).as_json

    assert_equal %w[email first_name id last_name role], json.keys.sort
    assert_not json.key?("encrypted_password")
    assert_not json.key?("jti")
  end
end
