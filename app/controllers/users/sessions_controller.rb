class Users::SessionsController < Devise::SessionsController
  # A dedicated store: the test environment's null_store would silently disable the limit.
  LOGIN_RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  respond_to :json

  rate_limit to: 10, within: 3.minutes, only: :create, store: LOGIN_RATE_LIMIT_STORE,
             by: -> { "#{request.remote_ip}:#{login_email}" },
             with: -> { render json: { errors: [ "Too many login attempts. Try again later." ] }, status: :too_many_requests }

  private

  # Keyed by IP and email, so a shared proxy IP cannot lock out every user at once.
  # params[:user] may be a plain string ({"user":"abc"}), so do not call dig on it.
  def login_email
    user = params[:user]
    user.is_a?(ActionController::Parameters) ? user[:email].to_s.strip.downcase : ""
  end

  def respond_with(resource, _opts = {})
    render json: { user: resource }, status: :ok
  end

  def respond_to_on_destroy(*)
    head :no_content
  end
end
