class AddSubnets < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_subnets, id: :uuid do |t|
      t.string :availability_zone, null: false
      t.integer :available_ip_address_count, default: 9999999
      t.string :cidr_block, null: false
      t.boolean :default_for_az, default: false
      t.string :subnet_id, null: false, index: true
      t.datetime :last_updated_at
      t.string :region_code
      t.belongs_to :aws_vpc, type: :uuid, index: true

      t.timestamps
    end
  end
end
