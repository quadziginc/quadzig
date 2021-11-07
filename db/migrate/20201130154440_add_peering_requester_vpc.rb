class AddPeeringRequesterVpc < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_peered_requester_vpcs, id: :uuid do |t|
      t.belongs_to :aws_peering_connection, type: :uuid
      t.string :cidr_block, null: false
      t.string :owner_id, null: false
      t.string :vpc_id, null: false, index: true
      t.string :region_code, null: false

      t.timestamps
    end
  end
end
