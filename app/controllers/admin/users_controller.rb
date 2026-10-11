class Admin::UsersController < Admin::BaseController
  def index
    render json: User.order(:id)
  end

  def show
    render json: User.find(params[:id])
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

  private

  def user_params
    params.expect(user: [ :first_name, :last_name, :email, :role ])
  end
end
