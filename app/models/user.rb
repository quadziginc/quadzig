class User < ApplicationRecord
  has_many :cognito_sessions
  has_many :aws_accounts, dependent: :destroy
  has_many :aws_ec2_instances, through: :aws_accounts
  has_one :subscription
  has_one :mfa_device
  has_many :resource_groups, dependent: :destroy
  has_many :aws_security_groups, through: :aws_accounts
  has_many :aws_ec2_security_groups, through: :aws_ec2_instances
  has_many :aws_lb_security_groups, through: :aws_accounts
  has_many :aws_elb_security_groups, through: :aws_accounts

  validate :check_ignored_aws_vpcs
  validates :email, uniqueness: true

  # MAKE SURE THIS ORDER IS PRESERVED
  after_create :_create_subscription
  after_create :create_stripe_user
  after_create_commit :create_default_rg

  delegate :free?, :enterprise?, to: :subscription, prefix: :subscription

  def in_early_access_period?
    return ($Emails.include? self.email) && (self.created_at + 93.days > DateTime.now)
  end

  def default_rg
    resource_groups.where(default: true).first
  end

  private

  # create_subscription is a method already made available
  # by activerecord because of has_one association
  def _create_subscription
    # Free tier does not have any limits on number of AWS Accounts
    self.create_subscription!(
      tier: "free",
      aws_account_quantity: 3
    )
  end

  def create_stripe_user
    # TODO: Should go into separate queue
    idem_key = SecureRandom.hex(20)
    StripeUserCreationWorker.perform_async(self.id, idem_key)
  end

  def check_ignored_aws_vpcs
    unless [[], [true]].include? ignored_aws_vpcs.map { |vpc_id| vpc_id.match?(/\Avpc-[0-9a-z]{8,17}\z/) }.uniq
      errors.add(:ignored_aws_vpcs, "one or more vpc ids are invalid.")
    end
  end

  def create_default_rg
    resource_groups.create(default: true, name: 'Default')
  end
end
