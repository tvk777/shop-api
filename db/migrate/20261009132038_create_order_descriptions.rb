class CreateOrderDescriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :orders_description do |t|
      t.references :order, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end
  end
end
