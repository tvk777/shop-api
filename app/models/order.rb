class Order < ApplicationRecord
  class InvalidOrder < StandardError; end

  belongs_to :user
  has_many :order_descriptions, dependent: :destroy, autosave: true, inverse_of: :order
  has_many :items, through: :order_descriptions

  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  def self.place!(user:, lines:)
    raise InvalidOrder, "Order must contain at least one item" if lines.blank?

    ids   = lines.map { |line| line[:item_id].to_i }
    items = Item.where(id: ids).index_by(&:id)

    missing = ids.reject { |id| items.key?(id) }
    raise InvalidOrder, "Items not found: #{missing.join(', ')}" if missing.any?

    order = Order.new(user: user)

    lines.each do |line|
      item = items.fetch(line[:item_id].to_i)
      order.order_descriptions.build(item: item, quantity: line[:quantity].to_i, unit_price: item.price)
    end

    order.amount = order.order_descriptions.sum { |line| line.unit_price * line.quantity }
    order.save!
    order
  rescue ActiveRecord::RecordInvalid => e
    raise InvalidOrder, e.message
  end

  def as_json(_options = nil)
    {
      id: id,
      amount: amount,
      created_at: created_at,
      items: order_descriptions.map do |line|
        {
          item_id: line.item_id,
          name: line.item.name,
          price: line.unit_price,
          quantity: line.quantity
        }
      end
    }
  end
end
