class AddIgw < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_igws, id: :uuid do |t|
      t.string :igw_id, null: false, index: true
      t.string :owner_id, null: false
      t.string :vpc_id, index: true
      t.string :region_code, null: false
      t.datetime :last_updated_at
      t.belongs_to :aws_account, type: :uuid

      t.timestamps
    end
  end
end
