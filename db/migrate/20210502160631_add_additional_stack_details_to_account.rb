class AddAdditionalStackDetailsToAccount < ActiveRecord::Migration[6.0]
  def change
    add_column :aws_accounts, :cf_stack_id, :string
    add_column :aws_accounts, :cf_region_code, :string
  end
end
