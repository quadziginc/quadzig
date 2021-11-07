class AddSubnetType < ActiveRecord::Migration[6.0]
  def change
    add_column :aws_subnets, :connectivity_type, :string
  end
end
