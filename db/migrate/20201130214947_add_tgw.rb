class AddTgw < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_tgws, id: :uuid do |t|
      t.string :tgw_id, null: false, index: true
      t.string :tgw_arn, null: false, index: true
      t.string :owner_id, null: false
      t.string :amz_side_asn, null: false
      t.boolean :auto_acc_shrd_attch
      t.json :tags
      t.string :region_code, null: false
      t.datetime :last_updated_at
      t.belongs_to :aws_account, type: :uuid, index: true

      t.timestamps
    end
  end
end
