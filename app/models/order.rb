class Order < ApplicationRecord
  class InvalidOrder < StandardError; end

  belongs_to :user
  has_many :order_descriptions, dependent: :destroy
  has_many :items, through: :order_descriptions

  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  def self.place!(user:, lines:)
    raise InvalidOrder, "Order must contain at least one item" if lines.blank?

    ids   = lines.map { |line| line[:item_id].to_i }
    items = Item.where(id: ids).index_by(&:id)

    missing = ids.reject { |id| items.key?(id) }
    raise InvalidOrder, "Items not found: #{missing.join(', ')}" if missing.any?

    transaction do
      order = user.orders.create!(amount: 0)
      total = 0

      lines.each do |line|
        item     = items[line[:item_id].to_i]
        quantity = line[:quantity].to_i
        order.order_descriptions.create!(item: item, quantity: quantity)
        total += item.price * quantity
      end

      order.update!(amount: total)
      order
    end
  rescue ActiveRecord::RecordInvalid => e
    raise InvalidOrder, e.message
  end
end
