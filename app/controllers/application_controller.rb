class ApplicationController < ActionController::API
  before_action :authenticate_user!, unless: :devise_controller?

  rescue_from ActiveRecord::RecordNotFound do
    render json: { errors: ["Not found"] }, status: :not_found
  end
end
