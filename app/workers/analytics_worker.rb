require 'csv'

class AnalyticsWorker
  include Sidekiq::Worker

  def perform
    CSV.open("/tmp/users.csv", "wb") do |csv|
      User.all.each do |user|
        csv << [
          user.id,
          user.email,
          user.subscriber,
          user.subscription.stripe_id
        ]
      end
    end
    CSV.open("/tmp/analytics.csv", "wb") do |csv|
      User.all.each do |user|
        user.aws_accounts.each do |account|
          csv << [
            user.email,
            user.subscriber,
            account.name,
            account.aws_vpcs.count,
            account.aws_peering_connections.count,
            account.aws_tgws.count,
            account.aws_tgw_attachments.count,
            account.aws_igws.count,
            account.aws_ngws.count,
            account.aws_rds_aurora_clusters.count,
            account.aws_rds_db_instances.count,
            account.aws_load_balancers.count,
            account.aws_ecs_clusters.count,
            account.aws_ecs_services.count,
            account.active_regions.join("|")
          ]
        end
      end
    end

    s3 = Aws::S3::Client.new(region: ENV['AWS_DEFAULT_REGION'])

    s3.put_object(
      body: File.open("/tmp/analytics.csv", "rb"),
      bucket: ENV['ANALYTICS_BUCKET_NAME'], 
      key: "analytics.csv"
    )

    s3.put_object(
      body: File.open("/tmp/users.csv", "rb"),
      bucket: ENV['ANALYTICS_BUCKET_NAME'], 
      key: "users.csv"
    )
  end
end