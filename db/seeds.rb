# THIS ENTIRE FILE SHOULD BE IDEMPOTENT
AWS_REGIONS = [
  { region_code: "us-east-2", full_name: "Ohio" },
  { region_code: "us-east-1", full_name: "N. Virginia" },
  { region_code: "us-west-1", full_name: "N. California" },
  { region_code: "us-west-2", full_name: "Oregon" },
  { region_code: "ap-south-1", full_name: "Mumbai" },
  { region_code: "ap-northeast-2", full_name: "Seoul" },
  { region_code: "ap-southeast-1", full_name: "Singapore" },
  { region_code: "ap-southeast-2", full_name: "Sydney" },
  { region_code: "ap-northeast-1", full_name: "Tokyo" },
  { region_code: "ca-central-1", full_name: "Central" },
  { region_code: "eu-central-1", full_name: "Frankfurt" },
  { region_code: "eu-west-1", full_name: "Ireland" },
  { region_code: "eu-west-2", full_name: "London" },
  { region_code: "eu-west-3", full_name: "Paris" },
  { region_code: "eu-north-1", full_name: "Stockholm" },
  { region_code: "sa-east-1", full_name: "São Paulo" }
  # TODO:
  # ec2.describe_vpcs calls in Verify Access worker fails when used with the following regions.
  # Figure out why.
  # { region_code: "ap-east-1", full_name: "Hong Kong" },
  # { region_code: "eu-south-1", full_name: "Milan" },
  # { region_code: "me-south-1", full_name: "Bahrain" }
]

AWS_AZS = {
  "us-east-2" => ["us-east-2a","us-east-2b","us-east-2c"],
  "us-east-1" => ["us-east-1a","us-east-1b","us-east-1c","us-east-1d","us-east-1e","us-east-1f"],
  "us-west-1" => ["us-west-1a","us-west-1c"],
  "us-west-2" => ["us-west-2a","us-west-2b","us-west-2c","us-west-2d"],
  "ap-south-1" => ["ap-south-1a","ap-south-1b","ap-south-1c"],
  "ap-northeast-2" => ["ap-northeast-2a","ap-northeast-2b","ap-northeast-2c","ap-northeast-2d"],
  "ap-southeast-1" => ["ap-southeast-1a","ap-southeast-1b","ap-southeast-1c"],
  "ap-southeast-2" => ["ap-southeast-2a","ap-southeast-2b","ap-southeast-2c"],
  "ap-northeast-1" => ["ap-northeast-1a","ap-northeast-1c","ap-northeast-1d"],
  "ca-central-1" => ["ca-central-1a","ca-central-1b","ca-central-1d"],
  "eu-central-1" => ["eu-central-1a","eu-central-1b","eu-central-1c"],
  "eu-west-1" => ["eu-west-1a","eu-west-1b","eu-west-1c"],
  "eu-west-2" => ["eu-west-2a","eu-west-2b","eu-west-2c"],
  "eu-west-3" => ["eu-west-3a","eu-west-3b","eu-west-3c"],
  "eu-north-1" => ["eu-north-1a","eu-north-1b","eu-north-1c"],
  "sa-east-1" => ["sa-east-1a","sa-east-1b","sa-east-1c"],
}

AWS_REGIONS.each do |region|
  # DO NOT USE CREATE! HERE
  # THIS WILL CAUSE THE db:seed COMMAND TO
  # ERROR OUT WHEN WE ADD NEW REGIONS
  AwsRegion.create(region)
end

AWS_AZS.each do |region, azs|
  region = AwsRegion.find_by(region_code: region)
  region.update(availability_zones: azs)
end
