class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users, id: :uuid do |t|
      t.string :subscriber, :null => false, index: {unique: true}
      t.string :email, null: false, index: true
      t.boolean :refresh_ongoing, default: false

      # TODO: These should eventually be separate model with extra attributes
      # like "description" etc.
      t.string :ignored_aws_vpcs, array: true, default: []
      t.string :ignored_aws_subnets, array: true, default: []
      t.boolean :ignore_default_vpcs, default: false
      t.references :subscription
      t.float :current_bill

      t.timestamps
    end
  end
end
