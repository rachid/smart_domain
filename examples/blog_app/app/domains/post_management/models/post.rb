class Post < ApplicationRecord
  include SmartDomain::Integration::ActiveRecord
  include SmartDomain::Integration::TenantScoped

  belongs_to :organization
  belongs_to :user

  validates :title, presence: true
  validates :body, presence: true

  scope :published, -> { where(published: true) }
  scope :draft, -> { where(published: false) }

  def publish!
    update!(published: true, published_at: Time.current)
  end

  def unpublish!
    update!(published: false, published_at: nil)
  end
end
