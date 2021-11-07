class Ec2ResiliencyFieldsV1 < ActiveRecord::Migration[6.0]
  def change
    add_column :aws_ec2_instances, :root_device_type, :string
    add_column :aws_ec2_instances, :virtualization_type, :string
  end
end
