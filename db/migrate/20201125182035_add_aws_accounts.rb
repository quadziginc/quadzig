class AddAwsAccounts < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_accounts, id: :uuid do |t|
      t.string :name
      t.string :account_id, index: true
      t.string :external_id, null: false
      t.string :active_regions, array: true, default: []
      # TODO: Add index

      # External Reference is no longer used
      t.string :ext_reference, null: false
      t.string :cf_stack_name, null: false

      # Used to signal that a IAM role is now provisioned in customer account
      # and Quadzig is aware of this IAM role.
      # At this stage, we have still not verified whether the role has the correct set of
      # permissions. Account creation may yet fail if the customer has changed/modified the cloudformation
      # template before creating the stack.
      t.boolean :role_associated, default: false
      t.string :iam_role_arn

      # Used to signal that the Cross Account Role provisioned has all the required permissions
      t.boolean :creation_complete, default: false
      t.belongs_to :user, type: :uuid, index: true, foreign_key: true
      t.timestamps

      # TODO: Index creation for this and all tables
    end
  end
end
