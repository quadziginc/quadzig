class AddDisplayConfigsLastSyncedToSecurityGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :aws_security_groups, :view_config, :json, default: {}
    add_column :aws_security_groups, :last_synced_at, :timestamp, null: false, default: -> { 'CURRENT_TIMESTAMP' }
  end
end
