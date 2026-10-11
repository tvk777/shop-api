class Admin::BaseController < ApplicationController
  before_action :require_admin!

  private

  def require_admin!
    render json: { errors: [ "Forbidden" ] }, status: :forbidden unless current_user.admin?
  end

  def render_errors(record)
    render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
  end
end
