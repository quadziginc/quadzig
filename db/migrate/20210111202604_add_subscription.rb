class AddSubscription < ActiveRecord::Migration[6.0]
  def change
    create_table :subscriptions, id: :uuid do |t|
      t.string :tier, null: false, default: :free
      t.string :stripe_id, index: true
      t.string :stripe_subscription_item_id
      t.string :stripe_subscription_id
      t.integer :aws_account_quantity

      t.belongs_to :user, type: :uuid
      t.timestamps
    end
  end
end
