class OrdersController < ApplicationController
  before_action :reject_admin!

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
    orders, meta = paginate(orders, default_per_page: 10)
    render json: { data: orders, meta: meta }
  end

  def show
    order = current_user.orders.includes(order_descriptions: :item).find(params[:id])
    render json: order
  end

  private

  # Admins manage users and items only; shopping is for regular users.
  def reject_admin!
    render json: { errors: [ "Admins cannot place or view orders" ] }, status: :forbidden if current_user.admin?
  end

  def order_lines
    params.expect(order: [ items: [ [ :item_id, :quantity ] ] ])[:items]
  end
end
