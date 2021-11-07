class Subscription < ApplicationRecord
  belongs_to :user

  enum tier: { free: 'free', enterprise: 'enterprise' }

  validates :aws_account_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :stripe_id, uniqueness: true, if: :stripe_id?
  validates :tier, inclusion: { in: tiers.values }
end