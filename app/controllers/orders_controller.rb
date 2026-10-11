class OrdersController < ApplicationController
  def create
    order = Order.place!(user: current_user, lines: order_lines)
    render json: order, status: :created
  rescue Order::InvalidOrder => e
    render json: { errors: [ e.message ] }, status: :unprocessable_entity
  end

  def index
    orders = current_user.orders
                         .includes(order_descriptions: :item)
                         .order(created_at: :desc, id: :desc)
    render json: orders
  end

  def show
    order = current_user.orders.includes(order_descriptions: :item).find(params[:id])
    render json: order
  end

  private

  def order_lines
    params.expect(order: [ items: [ [ :item_id, :quantity ] ] ])[:items]
  end
end
