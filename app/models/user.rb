class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :registerable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  enum :role, { user: 0, admin: 1 }, validate: true

  has_many :orders, dependent: :destroy

  validates :first_name, :last_name, presence: true

  PUBLIC_ATTRIBUTES = %i[id email first_name last_name role].freeze

  def as_json(options = nil)
    super({ only: PUBLIC_ATTRIBUTES }.merge(options || {}))
  end
end
