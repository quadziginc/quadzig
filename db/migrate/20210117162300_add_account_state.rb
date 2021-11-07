class AddAccountState < ActiveRecord::Migration[6.0]
  def change
    add_column :aws_accounts, :status, :string
    add_column :aws_accounts, :creation_errors, :string, array: true, default: []
  end
end
