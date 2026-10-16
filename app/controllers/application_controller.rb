class ApplicationController < ActionController::API
  class InvalidParameter < StandardError; end

  include Paginatable

  before_action :authenticate_user!, unless: :devise_controller?

  rescue_from ActiveRecord::RecordNotFound do
    render json: { errors: [ "Not found" ] }, status: :not_found
  end

  rescue_from InvalidParameter do |e|
    render json: { errors: [ e.message ] }, status: :bad_request
  end

  private

  # q must be a plain string; q[]=x or q[a]=x would otherwise reach the search scope.
  def search_param
    q = params[:q]
    raise InvalidParameter, "Invalid search parameter" unless q.nil? || q.is_a?(String)

    q
  end
end
