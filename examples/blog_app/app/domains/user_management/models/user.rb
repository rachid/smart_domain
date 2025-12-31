class User < ApplicationRecord
  include SmartDomain::Integration::ActiveRecord
  include SmartDomain::Integration::TenantScoped

  belongs_to :organization
  has_many :posts, dependent: :destroy

  validates :email, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :role, inclusion: { in: %w[admin editor viewer] }
end
