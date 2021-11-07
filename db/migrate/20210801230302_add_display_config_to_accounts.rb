class AddDisplayConfigToAccounts < ActiveRecord::Migration[6.0]
  def change
    add_column :aws_accounts, :view_config, :json, default: {}
  end
end
