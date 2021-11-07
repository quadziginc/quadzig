class AddIpAddressTypeToLb < ActiveRecord::Migration[6.0]
  def change
    add_column :aws_load_balancers, :ip_address_type, :string
  end
end
