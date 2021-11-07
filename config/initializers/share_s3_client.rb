if ENV['ASSET_PRECOMPILE'].to_i == 0
  $S3_RESOURCE = Aws::S3::Resource.new(region: ENV['AWS_DEFAULT_REGION'])
end