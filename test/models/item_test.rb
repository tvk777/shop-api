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

  test "price accepts the column maximum" do
    item = Item.new(name: "Max", price: BigDecimal("99999999.99"))
    assert item.valid?
  end

  test "price above the column maximum is invalid" do
    item = Item.new(name: "Too much", price: 100_000_000)
    assert_not item.valid?
    assert item.errors[:price].any?
  end

  test "database rejects a negative price" do
    assert_raises(ActiveRecord::StatementInvalid) do
      items(:coffee).update_columns(price: -1)
    end
  end
end
