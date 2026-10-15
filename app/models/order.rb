class Order < ApplicationRecord
  class InvalidOrder < StandardError; end

  MAX_AMOUNT = BigDecimal("99999999.99") # largest value of the decimal(10,2) column

  belongs_to :user
  has_many :order_descriptions, dependent: :destroy, autosave: true, inverse_of: :order
  has_many :items, through: :order_descriptions

  validates :amount, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_AMOUNT }

  def self.place!(user:, lines:)
    raise InvalidOrder, "Order must contain at least one item" if lines.blank?

    pairs = lines.map do |line|
      [ parse_integer(line[:item_id], "Item id"), parse_quantity(line[:quantity]) ]
    end
    ids = pairs.map(&:first)
    # Otherwise the same item on several lines would bypass the per-line quantity limit.
    raise InvalidOrder, "Each item can appear only once in an order" if ids.uniq.size != ids.size

    items = Item.where(id: ids).index_by(&:id)

    missing = ids.reject { |id| items.key?(id) }
    raise InvalidOrder, "Items not found: #{missing.join(', ')}" if missing.any?

    order = Order.new(user: user)

    pairs.each do |item_id, quantity|
      item = items.fetch(item_id)
      order.order_descriptions.build(item: item, quantity: quantity, unit_price: item.price)
    end

    order.amount = order.order_descriptions.sum { |line| line.unit_price * line.quantity }
    raise InvalidOrder, "Order total is too large" if order.amount > MAX_AMOUNT

    begin
      order.save!
    rescue ActiveRecord::InvalidForeignKey
      # An item was deleted after the lookup above; report it like any other missing item.
      missing = ids - Item.where(id: ids).pluck(:id)
      raise if missing.empty?

      raise InvalidOrder, "Items not found: #{missing.join(', ')}"
    end
    order
  rescue ActiveRecord::RecordInvalid
    # The known rules are checked above with their own messages; never expose internal model names.
    raise InvalidOrder, "Order could not be placed"
  end

  def self.parse_quantity(value)
    quantity = parse_integer(value, "Quantity")
    return quantity if quantity.between?(1, OrderDescription::MAX_QUANTITY)

    raise InvalidOrder, "Quantity must be between 1 and #{OrderDescription::MAX_QUANTITY}"
  end
  private_class_method :parse_quantity

  # Accepts an Integer or a string of digits only, so "2.7" or "12junk" are not truncated by to_i.
  def self.parse_integer(value, field)
    return value if value.is_a?(Integer)
    return value.to_i if value.is_a?(String) && value.match?(/\A\d+\z/)

    raise InvalidOrder, "#{field} must be a whole number"
  end
  private_class_method :parse_integer

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
