require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @headers = auth_headers_for(users(:alice))
  end

  test "missing or blank q returns all items" do
    [ {}, { q: "" } ].each do |params|
      get items_path, params: params, headers: @headers
      assert_response :ok
      assert_equal Item.count, response.parsed_body.size
    end
  end

  test "q filters items" do
    get items_path, params: { q: "espresso" }, headers: @headers

    assert_response :ok
    assert_equal [ "Espresso" ], response.parsed_body.map { |item| item["name"] }
  end

  test "a non-string q returns 400" do
    [ "q[]=x", "q[a]=x" ].each do |query|
      get "#{items_path}?#{query}", headers: @headers

      assert_response :bad_request
      assert_equal({ "errors" => [ "Invalid search parameter" ] }, response.parsed_body)
    end
  end
end
