class ProfilesController < ApplicationController
  def show
    render json: current_user
  end

  def update
    attrs = profile_params
    # Sending the current email (in any case, with surrounding spaces) is not a change.
    attrs = attrs.except(:email) if attrs.key?(:email) && attrs[:email].to_s.strip.casecmp?(current_user.email)

    if attrs.key?(:email) && (error = email_change_error(attrs[:current_password]))
      return render json: { errors: [ error ] }, status: :unprocessable_entity
    end

    if attrs[:password].present?
      change_password(attrs)
    elsif current_user.update(attrs.except(:password, :password_confirmation, :current_password))
      render json: current_user
    else
      render_errors
    end
  end

  private

  def profile_params
    params.expect(user: [ :first_name, :last_name, :email, :password, :password_confirmation, :current_password ])
  end

  # The new jti is saved in the same UPDATE (and transaction) as the new password, so every
  # token issued before is revoked. The current device gets a fresh token, encoded like at login.
  def change_password(attrs)
    current_user.jti = User.generate_jti
    return render_errors unless current_user.update_with_password(attrs)

    aud = Warden::JWTAuth::EnvHelper.aud_header(request.env)
    token, _payload = Warden::JWTAuth::UserEncoder.new.call(current_user, :user, aud)
    response.set_header("Authorization", "Bearer #{token}")
    render json: current_user
  end

  def email_change_error(current_password)
    if current_password.blank?
      "Current password is required to change your email"
    elsif !current_user.valid_password?(current_password)
      "Current password is invalid"
    end
  end

  def render_errors
    render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
  end
end
