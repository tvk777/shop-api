class OrdersController < ApplicationController
  def create
    order = Order.place!(user: current_user, lines: order_lines)
    render json: order_json(order), status: :created
  rescue Order::InvalidOrder => e
    render json: { errors: [e.message] }, status: :unprocessable_entity
  end

  def index
    orders = current_user.orders
                         .includes(order_descriptions: :item)
                         .order(created_at: :desc, id: :desc)
    render json: orders.map { |order| order_json(order) }
  end

  def show
    order = current_user.orders.includes(order_descriptions: :item).find(params[:id])
    render json: order_json(order)
  end

  private

  def order_lines
    params.require(:order).permit(items: [:item_id, :quantity])[:items]
  end

  def order_json(order)
    {
      id: order.id,
      amount: order.amount,
      created_at: order.created_at,
      items: order.order_descriptions.map do |line|
        {
          item_id: line.item_id,
          name: line.item.name,
          price: line.item.price,
          quantity: line.quantity
        }
      end
    }
  end
end