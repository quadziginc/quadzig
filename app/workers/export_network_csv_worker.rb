require 'zip'
require 'csv'

class ExportNetworkCsvWorker
  include Sidekiq::Worker

  def delete_csv_and_zip_files(export_id)
    csv_files = Dir.glob("/tmp/#{export_id}*.csv")
    zip_files = Dir.glob("/tmp/#{export_id}*.zip")
    csv_files.each { |f| File.delete(f) }
    zip_files.each { |f| File.delete(f) }
  end

  def create_vpc_csvs(export_id, resources, user)
    file_name = "#{export_id}-vpcs.csv"
    CSV.open("/tmp/#{export_id}-vpcs.csv", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "VPC Id",
        "Default",
        "Region Code",
        "CIDR Block",
        "Last Updated At(UTC)",
        "Tags"
      ]
      resources.each do |vpc|
        # TODO: we can probably improve performance by grouping vpcs by
        # AWS Account instead of triggering a query every time
        account = vpc.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          vpc.vpc_id,
          vpc.is_default,
          vpc.region_code,
          vpc.cidr_block,
          vpc.last_updated_at,
          vpc.tags ? vpc.tags.map { |e| "#{e['key']} - #{e['value']}" }.join('|') : ''
        ]
      end
    end
    return file_name
  end

  def create_subnet_csvs(export_id, resources, user)
    file_name = "#{export_id}-subnets.csv"
    CSV.open("/tmp/#{export_id}-subnets.csv", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "Subnet Id",
        "Availability Zone",
        "Available Ip Address Count",
        "CIDR Block",
        "Connectivity Type",
        "Region Code",
        "Last Updated At(UTC)",
      ]
      resources.each do |subnet|
        account = subnet.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          subnet.subnet_id,
          subnet.availability_zone,
          subnet.available_ip_address_count,
          subnet.cidr_block,
          subnet.connectivity_type,
          subnet.region_code,
          subnet.last_updated_at,
        ]
      end
    end
    return file_name
  end

  def create_igw_csvs(export_id, resources, user)
    file_name = "#{export_id}-igws.csv"
    CSV.open("/tmp/#{export_id}-igws.csv", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "Igw Id",
        "Vpc Id",
        "Owner Id",
        "Region Code",
        "Last Updated At(UTC)",
      ]
      resources.each do |igw|
        account = igw.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          igw.igw_id,
          igw.vpc_id,
          igw.owner_id,
          igw.region_code,
          igw.last_updated_at,
        ]
      end
    end
    return file_name
  end

  def create_ngw_csvs(export_id, resources, user)
    file_name = "#{export_id}-ngws.csv"
    CSV.open("/tmp/#{export_id}-ngws.csv", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "NGW Id",
        "VPC Id",
        "Region Code",
        "Subnet Id",
        "Last Updated At(UTC)",
      ]
      resources.each do |ngw|
        account = ngw.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          ngw.ngw_id,
          ngw.vpc_id,
          ngw.region_code,
          ngw.subnet_id,
          ngw.last_updated_at,
        ]
      end
    end
    return file_name
  end

  def create_tgw_csvs(export_id, resources, user)
    file_name = "#{export_id}-tgws.csv"
    CSV.open("/tmp/#{export_id}-tgws.csv", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "TGW Id",
        "TGW Arn",
        "Owner Id",
        "Amz Side Asn",
        "Auto Accept Attachments",
        "Region Code",
        "Last Updated At(UTC)",
        "Tags"
      ]
      resources.each do |tgw|
        account = tgw.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          tgw.tgw_id,
          tgw.tgw_arn,
          tgw.owner_id,
          tgw.amz_side_asn,
          tgw.auto_acc_shrd_attch,
          tgw.region_code,
          tgw.last_updated_at,
          tgw.tags ? tgw.tags.map { |e| "#{e['key']} - #{e['value']}" }.join('|') : ''
        ]
      end
    end
    return file_name
  end

  def create_peering_csvs(export_id, resources, user)
    file_name = "#{export_id}-vpc-peerings.csv"
    CSV.open("/tmp/#{export_id}-vpc-peerings.csv", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "Peering Id",
        "Region Code",
        "Accepter Cidr Block",
        "Accepter Owner Id",
        "Accepter Vpc Id",
        "Accepter Region Code",
        "Requester Cidr Block",
        "Requester Owner Id",
        "Requester Vpc Id",
        "Requester Region Code",
        "Last Updated At(UTC)",
      ]
      resources.each do |conn|
        account = conn.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          conn.peering_id,
          conn.region_code,
          conn.accepter_vpc.cidr_block,
          conn.accepter_vpc.owner_id,
          conn.accepter_vpc.vpc_id,
          conn.accepter_vpc.region_code,
          conn.requester_vpc.cidr_block,
          conn.requester_vpc.owner_id,
          conn.requester_vpc.vpc_id,
          conn.requester_vpc.region_code,
          conn.last_updated_at,
        ]
      end
    end
    return file_name
  end

  def create_tgw_attch_csvs(export_id, resources, user)
    file_name = "#{export_id}-tgw-attachments.csv"
    CSV.open("/tmp/#{export_id}-tgw-attachments.csv", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "Tgw Attch Id",
        "Tgw Id",
        "Tgw Owner Id",
        "Region Code",
        "Resource Owner Id",
        "Resource Type",
        "Resource Id",
        "State",
        "Last Updated At(UTC)",
        "Tags"
      ]
      resources.each do |tgw_attch|
        account = tgw_attch.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          tgw_attch.tgw_attch_id,
          tgw_attch.tgw_id,
          tgw_attch.tgw_owner_id,
          tgw_attch.region_code,
          tgw_attch.resource_owner_id,
          tgw_attch.resource_type,
          tgw_attch.resource_id,
          tgw_attch.state,
          tgw_attch.last_updated_at,
          tgw_attch.tags ? tgw_attch.tags.map { |e| "#{e['key']} - #{e['value']}" }.join('|') : ''
        ]
      end
    end
    return file_name
  end

  def create_zip_file(export_id, csv_files)
    zipfile_path = "/tmp/#{export_id}.zip"
    zipfile_name = File.basename(zipfile_path)

    Zip::File.open(zipfile_path, Zip::File::CREATE) do |zipfile|
      csv_files.compact.uniq.each do |file_path|
        zipfile.add(file_path, "/tmp/#{file_path}")
      end
    end

    return zipfile_path
  end

  def create_s3_exp_url(zipfile_path, user_id)
    zipfile_name = File.basename(zipfile_path)
    key = "csvs/#{user_id}/#{zipfile_name}"

    s3 = Aws::S3::Client.new(
      region: ENV['AWS_DEFAULT_REGION']
    )

    s3.put_object(
      body: File.open(zipfile_path, "rb"),
      key: key,
      bucket: ENV['SHARE_S3_BUCKET']
    )

    signer = Aws::S3::Presigner.new(client: s3)
    url = signer.presigned_url(
      :get_object,
      bucket: ENV['SHARE_S3_BUCKET'],
      key: key,
      expires_in: 86400
    )

    return url
  end

  def perform(user_id, resource_info)
    user = User.find(user_id)
    grouped_resource_ids = resource_info.group_by { |r| r["nodeType"] }
    export_id = SecureRandom.uuid
    csv_files = []

    # TODO: Add Console link to each of these
    grouped_resource_ids.each do |resource_type, resource_ids|
      ids = resource_info.map { |r| r["id"] }
      if resource_type == "vpc"
        vpc_resources = AwsVpc.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_vpc_csvs(export_id, vpc_resources, user)
      elsif resource_type == "subnet"
        subnet_resources = AwsSubnet.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_subnet_csvs(export_id, subnet_resources, user)
      elsif resource_type == "igw"
        igw_resources = AwsIgw.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_igw_csvs(export_id, igw_resources, user)
      elsif resource_type == "ngw"
        ngw_resources = AwsNgw.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_ngw_csvs(export_id, ngw_resources, user)
      elsif resource_type == "tgw"
        tgw_resources = AwsTgw.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_tgw_csvs(export_id, tgw_resources, user)
      elsif resource_type == "peering"
        peering_resources = AwsPeeringConnection.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_peering_csvs(export_id, peering_resources, user)
      elsif resource_type == "tgwattch"
        tgw_attch_resources = AwsTgwAttachment.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_tgw_attch_csvs(export_id, tgw_attch_resources, user)
      end
    end

    zipfile_path = create_zip_file(export_id, csv_files)
    s3_exp_url = create_s3_exp_url(zipfile_path, user_id)
    delete_csv_and_zip_files(export_id)

    # This should be the last step of the worker
    # If we do this before delete and other housekeeping tasks, we may
    # bombard the user with mails as sidekiq retries and repeats mail sends
    mail = UsersMailer.infrastructure_csv(s3_exp_url.to_s, user.email)
    mail.deliver_later
  end
end