class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :registerable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  enum :role, { user: 0, admin: 1 }

  has_many :orders, dependent: :destroy

  validates :first_name, :last_name, presence: true
end