class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :registerable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  enum :role, { user: 0, admin: 1 }, validate: true

  has_many :orders, dependent: :destroy

  # Prepended so it runs before the orders are destroyed; destroy runs in one transaction anyway.
  before_destroy :ensure_another_admin_remains, prepend: true

  validates :first_name, :last_name, presence: true

  scope :with_orders_count, lambda {
    left_joins(:orders).select("users.*, COUNT(orders.id) AS orders_count").group(:id)
  }

  PUBLIC_ATTRIBUTES = %i[id email first_name last_name role].freeze

  def as_json(options = nil)
    super({ only: PUBLIC_ATTRIBUTES }.merge(options || {}))
  end

  private

  # Locks the admin rows so two concurrent deletions cannot remove the last two admins.
  def ensure_another_admin_remains
    return unless admin?
    return if User.admin.lock.ids.any? { |admin_id| admin_id != id }

    errors.add(:base, "At least one admin is required")
    throw :abort
  end
end
