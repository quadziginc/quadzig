class AddEc2Instances < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_ec2_instances, id: :uuid do |t|
      t.string :image_id
      t.string :instance_id, null: false, index: true
      t.string :instance_type, null: false
      t.string :key_name
      t.datetime :launch_time
      t.string :platform
      t.string :private_dns_name
      t.string :private_ip_address
      t.string :public_dns_name
      t.string :public_ip_address
      t.string :state
      t.string :subnet_id, null: false, index: true
      t.string :vpc_id, null: false, index: true
      t.string :architecture
      t.string :iam_instance_profile_arn
      t.string :iam_instance_profile_id
      t.string :region_code, null: false
      t.boolean :source_dest_check

      t.json :security_groups
      t.json :tags
      t.belongs_to :aws_subnet, type: :uuid
      t.timestamps
    end
  end
end
