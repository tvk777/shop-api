class AddCheckConstraints < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :orders_description, "quantity > 0", name: "orders_description_quantity_positive"
    add_check_constraint :orders_description, "unit_price >= 0", name: "orders_description_unit_price_non_negative"
    add_check_constraint :items, "price >= 0", name: "items_price_non_negative"
    add_check_constraint :orders, "amount >= 0", name: "orders_amount_non_negative"
  end
end
