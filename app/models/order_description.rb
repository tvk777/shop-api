class OrderDescription < ApplicationRecord
  self.table_name = "orders_description"

  MAX_QUANTITY = 99

  belongs_to :order
  belongs_to :item

  validates :quantity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_QUANTITY }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
end
