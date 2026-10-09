class Order < ApplicationRecord
  belongs_to :user
  has_many :order_descriptions, dependent: :destroy
  has_many :items, through: :order_descriptions
end
