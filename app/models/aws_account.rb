class AwsAccount < ApplicationRecord
  # This is stupid. This callback HAS TO BE DEFINED
  # before the assocation definitions that have dependent_destroy
  # See https://stackoverflow.com/a/31344318 for more information
  before_destroy :clean_elasticsearch_cluster

  default_scope -> { where(role_associated: true) }
  # TODO: Validations
  belongs_to :user
  has_many :aws_vpcs, dependent: :destroy
  has_many :aws_peering_connections, dependent: :destroy
  has_many :aws_tgws, dependent: :destroy
  has_many :aws_tgw_attachments, dependent: :destroy
  has_many :aws_igws, dependent: :destroy
  has_many :aws_ngws, dependent: :destroy
  has_many :aws_rds_aurora_clusters, dependent: :destroy
  has_many :aws_rds_db_instances, dependent: :destroy
  has_many :aws_load_balancers, dependent: :destroy
  has_many :aws_ecs_clusters, dependent: :destroy
  has_many :aws_ecs_services, dependent: :destroy
  has_many :aws_subnets, dependent: :destroy
  has_many :aws_ec2_instances, dependent: :destroy
  has_many :aws_ec2_asgs, dependent: :destroy
  has_many :aws_elbs, dependent: :destroy
  has_many :aws_eks_clusters, dependent: :destroy
  has_many :aws_eks_nodegroups, dependent: :destroy
  has_many :aws_elasticache_clusters, dependent: :destroy
  has_many :aws_elasticache_replication_groups, dependent: :destroy
  has_many :aws_security_groups, through: :aws_vpcs, dependent: :destroy
  has_many :aws_ec2_security_groups, through: :aws_ec2_instances
  has_many :aws_lb_security_groups, through: :aws_load_balancers
  has_many :aws_elb_security_groups, through: :aws_elbs

  # TODO: Is this the right association?
  belongs_to :cf_template_version, optional: true

  with_options if: :role_associated do |account|
    account.validates :name, presence: true
    account.validates :name, format: { with: /\A[a-zA-Z0-9-_\s]+\z/, message: 'cannot have special characters.'}
    account.validates :name, length: { minimum: 3, message: 'should have a minimum of 3 characters' }

    account.validates :iam_role_arn, presence: true
    account.validates :iam_role_arn, format: { with: /\Aarn:aws:iam::[0-9]{12}:role\/(.+)[^\s]\z/, message: 'is invalid(Ensure there are no whitespaces at the end of the Role ARN)'}
  end

  validates :account_id, uniqueness: { scope: [:user_id, :role_associated] }, if: :account_id?
  # TODO: Check if external id has to be unique with a user scope. External ID should be unique
  # validates :external_id, uniqueness: { scope: [:user_id] }, if: :exteranl_id?

  validate :valid_active_regions

  after_create :assoc_cf_template_version

  private

  def assoc_cf_template_version
    self.cf_template_version = CfTemplateVersion.where(is_latest: true).first
    self.save
  end

  def valid_regions
    %w(us-east-2 us-east-1 us-west-1 us-west-2 ap-south-1 ap-northeast-2 ap-southeast-1 ap-southeast-2 ap-northeast-1 ca-central-1 eu-central-1 eu-west-1 eu-west-2 eu-west-3 eu-north-1 sa-east-1)
  end

  def clean_elasticsearch_cluster
    ids = []
    ids.concat self.aws_vpcs.pluck(:id)
    ids.concat self.aws_peering_connections.pluck(:id)
    ids.concat self.aws_tgws.pluck(:id)
    ids.concat self.aws_tgw_attachments.pluck(:id)
    ids.concat self.aws_igws.pluck(:id)
    ids.concat self.aws_ngws.pluck(:id)
    ids.concat self.aws_rds_aurora_clusters.pluck(:id)
    ids.concat self.aws_rds_db_instances.pluck(:id)
    ids.concat self.aws_load_balancers.pluck(:id)
    ids.concat self.aws_ecs_clusters.pluck(:id)
    ids.concat self.aws_ecs_services.pluck(:id)
    ids.concat self.aws_subnets.pluck(:id)
    ids.concat self.aws_ec2_instances.pluck(:id)

    CleanElasticsearchClusterWorker.perform_async(ids, self.user.id)
  end

  def valid_active_regions
    if active_regions == []
      self.active_regions = ["us-east-1"]
    end
    unless active_regions.map { |region_code| valid_regions.include? region_code }.uniq == [true]
      errors.add(:active_regions, "should be a valid AWS Region code.")
    end
  end
end
