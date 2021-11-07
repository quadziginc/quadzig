class AddNgws < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_ngws, id: :uuid do |t|
      t.string :ngw_id, null: false, index: true
      t.string :vpc_id, null: false, index: true
      t.json :addresses
      t.string :subnet_id, index: true
      t.string :region_code, null: false
      t.datetime :last_updated_at
      t.belongs_to :aws_account, type: :uuid

      t.timestamps
    end
  end
end
