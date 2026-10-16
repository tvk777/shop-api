require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @headers = auth_headers_for(users(:alice))
  end

  test "missing or blank q returns all items" do
    [ {}, { q: "" } ].each do |params|
      get items_path, params: params, headers: @headers
      assert_response :ok
      assert_equal Item.count, response.parsed_body["data"].size
    end
  end

  test "q filters items" do
    get items_path, params: { q: "espresso" }, headers: @headers

    assert_response :ok
    assert_equal [ "Espresso" ], response.parsed_body["data"].map { |item| item["name"] }
  end

  test "a non-string q returns 400" do
    [ "q[]=x", "q[a]=x" ].each do |query|
      get "#{items_path}?#{query}", headers: @headers

      assert_response :bad_request
      assert_equal({ "errors" => [ "Invalid search parameter" ] }, response.parsed_body)
    end
  end

  INVALID_PAGINATION = { "errors" => [ "Invalid pagination parameters" ] }.freeze

  test "paginates with the default per_page of 12" do
    create_items(13)
    expected = Item.order(:name, :id).pluck(:name)

    get items_path, headers: @headers
    assert_response :ok
    assert_equal expected.first(12), response.parsed_body["data"].map { |item| item["name"] }
    assert_equal({ "page" => 1, "per_page" => 12, "total" => 15, "total_pages" => 2 }, response.parsed_body["meta"])

    get items_path, params: { page: 2 }, headers: @headers
    assert_response :ok
    assert_equal expected.last(3), response.parsed_body["data"].map { |item| item["name"] }
    assert_equal({ "page" => 2, "per_page" => 12, "total" => 15, "total_pages" => 2 }, response.parsed_body["meta"])
  end

  test "list items keep their fields" do
    get items_path, headers: @headers

    assert_equal %w[description id name price], response.parsed_body["data"].first.keys.sort
  end

  test "a page beyond the last returns empty data with the correct meta" do
    [ "3", "99999999999999999999" ].each do |page|
      get items_path, params: { page: page, per_page: 1 }, headers: @headers

      assert_response :ok
      assert_equal [], response.parsed_body["data"]
      assert_equal({ "page" => page.to_i, "per_page" => 1, "total" => 2, "total_pages" => 2 }, response.parsed_body["meta"])
    end
  end

  test "an empty result is page 1 of 1" do
    get items_path, params: { q: "no such item" }, headers: @headers

    assert_response :ok
    assert_equal [], response.parsed_body["data"]
    assert_equal({ "page" => 1, "per_page" => 12, "total" => 0, "total_pages" => 1 }, response.parsed_body["meta"])
  end

  test "custom per_page, 50 accepted and 51 rejected" do
    create_items(3)

    get items_path, params: { page: "2", per_page: "2" }, headers: @headers
    assert_response :ok
    assert_equal Item.order(:name, :id).offset(2).limit(2).pluck(:id), response.parsed_body["data"].map { |item| item["id"] }
    assert_equal({ "page" => 2, "per_page" => 2, "total" => 5, "total_pages" => 3 }, response.parsed_body["meta"])

    get items_path, params: { per_page: 50 }, headers: @headers
    assert_response :ok
    assert_equal 50, response.parsed_body["meta"]["per_page"]

    get items_path, params: { per_page: 51 }, headers: @headers
    assert_response :bad_request
    assert_equal INVALID_PAGINATION, response.parsed_body
  end

  test "invalid page and per_page values return 400" do
    queries = %w[page=0 page=-1 page=abc page=2.5 page= page=1x page[]=1 page[a]=1
                 per_page=0 per_page=-5 per_page=abc per_page=2.5 per_page=51 per_page[]=10]
    queries.each do |query|
      get "#{items_path}?#{query}", headers: @headers

      assert_response :bad_request, query
      assert_equal INVALID_PAGINATION, response.parsed_body, query
    end
  end

  test "q and page work together and total counts only matches" do
    create_items(5, prefix: "Kenya")

    get items_path, params: { q: "kenya", page: 2, per_page: 2 }, headers: @headers

    assert_response :ok
    assert_equal [ "Kenya 03", "Kenya 04" ], response.parsed_body["data"].map { |item| item["name"] }
    assert_equal({ "page" => 2, "per_page" => 2, "total" => 5, "total_pages" => 3 }, response.parsed_body["meta"])
  end

  test "items with the same name are ordered by id" do
    ids = 3.times.map { Item.create!(name: "Same", price: 1).id }

    seen = []
    3.times do |i|
      get items_path, params: { q: "same", page: i + 1, per_page: 1 }, headers: @headers
      seen.concat(response.parsed_body["data"].map { |item| item["id"] })
    end
    assert_equal ids.sort, seen
  end

  private

  def create_items(count, prefix: "Item")
    count.times { |i| Item.create!(name: format("%s %02d", prefix, i + 1), price: 1) }
  end
end
