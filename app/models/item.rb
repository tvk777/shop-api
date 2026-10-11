class Item < ApplicationRecord
  has_many :order_descriptions, dependent: :restrict_with_error
  has_many :orders, through: :order_descriptions

  scope :search, lambda { |q|
    next all if q.blank?

    term = "%#{sanitize_sql_like(q)}%"
    where("name ILIKE :term OR description ILIKE :term", term: term)
  }

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
end
