class MfaDevice < ApplicationRecord
  belongs_to :user, optional: true

  validates :device_name, format: { with: /\A[[A-Z0-9a-z\d\-_\s]]+\Z/ }
end