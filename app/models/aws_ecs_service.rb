class AwsEcsService < ApplicationRecord
  belongs_to :aws_account
  belongs_to :aws_ecs_cluster
  has_many :aws_security_groups, as: :aws_resource, dependent: :destroy

  track_issues high: [
    proc { |obj|
      { deployment_circuit_breaker: 'disabled' } unless obj.deployment_configuration.dig('deployment_circuit_breaker','enable')
    },
    proc { |obj| { failed_tasks: obj.failed_tasks } if obj.failed_tasks.positive? },
    proc { |obj|
      if obj.deployment_configuration['minimum_healthy_percent'] < 50
        { minimum_healthy_percent: obj.deployment_configuration['minimum_healthy_percent'] }
      end
    },
  ], medium: [
    proc { |obj|
      if obj.deployment_configuration['minimum_healthy_percent'] < 75
        { minimum_healthy_percent: obj.deployment_configuration['minimum_healthy_percent'] }
      end
    },
    proc { |obj|
      unless obj.deployment_configuration.dig('deployment_circuit_breaker', 'rollback')
        { deployment_circuit_breaker_rollback: 'disabled' }
      end
    }
  ]

  def failed_tasks
    return @failed_tasks if @failed_tasks

    primary_deployment = deployments.detect { |d| d['status'] == 'PRIMARY' }
    @failed_tasks = primary_deployment ? primary_deployment['failed_tasks'] : 0
  end

  def medium_severity_issues
    return @medium_severity_issues unless @medium_severity_issues.blank?

    @medium_severity_issues = []
    unless deployment_configuration.dig('deployment_circuit_breaker', 'rollback')
      @medium_severity_issues << { deployment_circuit_breaker: 'disabled' }
    end

    @medium_severity_issues
  end

  def aws_subnets
    self.aws_account.aws_subnets.where(subnet_id: self.network_configuration.to_h.fetch('awsvpc_configuration', {}).fetch('subnets', []))
  end

  def is_split_across_subnets
    true
  end
end