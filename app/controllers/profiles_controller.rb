class ProfilesController < ApplicationController
  def show
    render json: current_user
  end

  def update
    attrs = profile_params
    updated = if attrs[:password].present?
      current_user.update_with_password(attrs)
    else
      current_user.update(attrs.except(:password, :password_confirmation, :current_password))
    end

    if updated
      render json: current_user
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.expect(user: [ :first_name, :last_name, :email, :password, :password_confirmation, :current_password ])
  end
end
