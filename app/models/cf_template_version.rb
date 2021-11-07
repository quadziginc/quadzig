class CfTemplateVersion < ApplicationRecord
  validates :cf_link, presence: true, uniqueness: true
  validates :version, presence: true, uniqueness: true
  validates :is_latest, uniqueness: true, if: :is_latest
end