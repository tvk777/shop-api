class AddUnitPriceToOrdersDescription < ActiveRecord::Migration[8.1]
  def up
    add_column :orders_description, :unit_price, :decimal, precision: 10, scale: 2

    execute <<~SQL
      UPDATE orders_description
      SET unit_price = items.price
      FROM items
      WHERE items.id = orders_description.item_id
    SQL

    change_column_null :orders_description, :unit_price, false
  end

  def down
    remove_column :orders_description, :unit_price
  end
end
