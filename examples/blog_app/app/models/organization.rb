class Organization < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :posts, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
