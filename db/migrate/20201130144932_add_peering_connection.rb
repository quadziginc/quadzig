class AddPeeringConnection < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_peering_connections, id: :uuid do |t|
      t.belongs_to :aws_account, type: :uuid
      t.string :peering_id, null: false, index: true
      t.string :region_code, null: false
      t.datetime :last_updated_at
      t.references :aws_peered_requester_vpc, type: :uuid
      t.references :aws_peered_accepter_vpc, type: :uuid

      t.timestamps
    end
  end
end
