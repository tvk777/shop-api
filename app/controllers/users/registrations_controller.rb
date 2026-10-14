class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  private

  # The API authenticates with the JWT only, so do not keep the new user in the cookie session.
  def sign_up(resource_name, resource)
    sign_in(resource_name, resource, store: false)
  end

  def sign_up_params
    params.expect(user: [ :first_name, :last_name, :email, :password, :password_confirmation ])
  end

  def respond_with(resource, _opts = {})
    if resource.persisted?
      render json: { user: resource }, status: :created
    else
      render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
