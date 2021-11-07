class CfTemplateVersionsCreatorWorker
  include Sidekiq::Worker

  def perform
    stack_bucket_name = ENV['CF_STACK_BUCKET']
    if stack_bucket_name.nil?
      raise StandardError.new("Cloudformation Stack Bucket for cross account access role not set!")
    end
    cf_template_versions = [
      {
        cf_link: "https://#{stack_bucket_name}.s3-us-west-1.amazonaws.com/secure_access.yml",
        version: "1",
        is_latest: false
      },
      {
        cf_link: "https://#{stack_bucket_name}.s3-us-west-1.amazonaws.com/secure_access-c3f1e4f0bd.yml",
        version: "2",
        is_latest: false
      },
      {
        cf_link: "https://#{stack_bucket_name}.s3-us-west-1.amazonaws.com/secure_access-c28e30d3a6.yml",
        version: "3",
        is_latest: true
      }
    ]

    cf_template_versions.each do |version|
      template_version = CfTemplateVersion.find_by(cf_link: version[:cf_link])
      if template_version
        template_version.update(version)
      else
        CfTemplateVersion.create(version)
      end
    end

    AwsAccount.find_each do |account|
      next if account.cf_template_version
      cf_template_version = CfTemplateVersion.where(version: "1").first
      account.update(cf_template_version: cf_template_version)
    end
  end
end