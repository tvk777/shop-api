class Users::SessionsController < Devise::SessionsController
  respond_to :json

  private

  def respond_with(resource, _opts = {})
    render json: { user: user_json(resource) }, status: :ok
  end

  def respond_to_on_destroy(*)
    head :no_content
  end

  def user_json(user)
    user.slice(:id, :email, :first_name, :last_name, :role)
  end
end