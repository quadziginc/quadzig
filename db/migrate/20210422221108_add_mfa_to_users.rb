class AddMfaToUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :mfa_devices, id: :uuid do |t|
      t.string :device_name, null: false

      t.belongs_to :user, type: :uuid
      t.timestamps
    end
  end
end
