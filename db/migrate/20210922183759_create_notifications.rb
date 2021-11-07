class CreateNotifications < ActiveRecord::Migration[6.0]
  def change
    create_table :notifications do |t|
      t.text :message
      t.string :type, default: 'web'
      t.timestamp :valid_from, default: -> { 'CURRENT_TIMESTAMP' }, null: false
      t.timestamp :valid_till, default: -> { "(CURRENT_TIMESTAMP + '1 DAY'::interval)" }, null: false

      t.timestamps
    end
  end
end
