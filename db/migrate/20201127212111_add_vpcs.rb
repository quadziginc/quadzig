class AddVpcs < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_vpcs, id: :uuid do |t|
      t.string :vpc_id, null: false, index: true
      t.boolean :is_default
      t.json :tags
      t.string :region_code, null: false
      t.datetime :last_updated_at
      t.string :cidr_block, null: false
      t.belongs_to :aws_account, type: :uuid

      t.timestamps
    end
  end
end
