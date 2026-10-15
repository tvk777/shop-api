class Admin::UsersController < Admin::BaseController
  ADMIN_ATTRIBUTES = (User::PUBLIC_ATTRIBUTES + %i[orders_count]).freeze

  def index
    render json: User.with_orders_count.order(:id).as_json(only: ADMIN_ATTRIBUTES)
  end

  def show
    render json: User.with_orders_count.find(params[:id]).as_json(only: ADMIN_ATTRIBUTES)
  end

  def update
    user = User.find(params[:id])
    attrs = user_params

    if user == current_user && attrs[:role].present? && attrs[:role] != "admin"
      return render json: { errors: [ "Admins cannot remove their own admin role" ] }, status: :unprocessable_entity
    end

    if user.update(attrs)
      render json: user
    else
      render_errors(user)
    end
  end

  def destroy
    user = User.find(params[:id])

    if user == current_user
      return render json: { errors: [ "You cannot delete your own account" ] }, status: :unprocessable_entity
    end

    if user.destroy
      head :no_content
    else
      render_errors(user)
    end
  end

  private

  def user_params
    params.expect(user: [ :first_name, :last_name, :email, :role ])
  end
end
