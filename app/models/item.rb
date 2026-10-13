class Item < ApplicationRecord
  has_many :order_descriptions, dependent: :restrict_with_error
  has_many :orders, through: :order_descriptions

  scope :search, lambda { |q|
    next all if q.blank?

    term = "%#{sanitize_sql_like(q)}%"
    where("name ILIKE :term OR description ILIKE :term", term: term)
  }

  PUBLIC_ATTRIBUTES = %i[id name description price].freeze
  MAX_PRICE = BigDecimal("99999999.99") # largest value of the decimal(10,2) column

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_PRICE }

  def as_json(options = nil)
    super({ only: PUBLIC_ATTRIBUTES }.merge(options || {}))
  end
end
