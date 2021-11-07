# if ENV['ASSET_PRECOMPILE'].to_i == 1
#   s3 = Aws::S3::Client.new(region: 'us-west-1')
#   temp = s3.get_object(bucket: 'temp-early-access-users', key: 'earlyaccess.txt')
#   $Emails = temp.body.read.split
# end

$Emails = []