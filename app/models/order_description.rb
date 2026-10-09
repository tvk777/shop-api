class OrderDescription < ApplicationRecord
  self.table_name = "orders_description"

  belongs_to :order
  belongs_to :item

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
end
