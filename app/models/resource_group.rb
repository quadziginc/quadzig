class ResourceGroup < ApplicationRecord
  belongs_to :user

  validates_uniqueness_of :default, scope: :user, if: :default?
  validates_uniqueness_of :name, scope: :user
  validates :name, length: { in: 3..60 }

  scope :edges_for, ->(resource_id, direction) { where("display_config ->> 'edges' LIKE ?", "%#{direction}%#{resource_id}%") }
  scope :custom, ->{ where(default: false) }
end
