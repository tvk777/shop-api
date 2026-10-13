class ChangeOrdersDescriptionQuantityCheck < ActiveRecord::Migration[8.1]
  # PostgreSQL validates existing rows when the constraint is added, so the
  # migration fails (and rolls back) if any line has a quantity above 99.
  def change
    remove_check_constraint :orders_description, "quantity > 0", name: "orders_description_quantity_positive"
    add_check_constraint :orders_description, "quantity BETWEEN 1 AND 99", name: "orders_description_quantity_range"
  end
end
