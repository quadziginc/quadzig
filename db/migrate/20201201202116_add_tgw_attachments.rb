class AddTgwAttachments < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_tgw_attachments, id: :uuid do |t|
      t.belongs_to :aws_account, type: :uuid
      t.datetime :last_updated_at
      t.string :tgw_attch_id, index: true
      t.string :tgw_id
      t.string :tgw_owner_id
      t.string :region_code
      t.string :resource_owner_id
      t.string :resource_type
      t.string :resource_id
      t.string :state
      t.json :tags

      t.timestamps
    end
  end
end
