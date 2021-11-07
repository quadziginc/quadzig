class AwsRegion < ApplicationRecord
  validates :full_name, presence: true
  validates :region_code, presence: true, uniqueness: true
end