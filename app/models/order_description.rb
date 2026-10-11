class OrderDescription < ApplicationRecord
  self.table_name = "orders_description"

  belongs_to :order
  belongs_to :item

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
end
