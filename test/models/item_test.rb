require "test_helper"

class ItemTest < ActiveSupport::TestCase
  test "search returns all items for a blank query" do
    assert_equal Item.count, Item.search("").count
    assert_equal Item.count, Item.search(nil).count
  end

  test "search matches name and description case-insensitively" do
    assert_equal [ items(:coffee) ], Item.search("espresso").to_a
    assert_equal [ items(:tea) ], Item.search("LIGHT").to_a
  end

  test "search escapes LIKE wildcards" do
    assert_empty Item.search("%")
    assert_empty Item.search("_")
  end

  test "database rejects a negative price" do
    assert_raises(ActiveRecord::StatementInvalid) do
      items(:coffee).update_columns(price: -1)
    end
  end
end
