class AddCardDetails < ActiveRecord::Migration[6.0]
  def change
    add_column :subscriptions, :last_card_digits, :string
    add_column :subscriptions, :card_expiry_year, :string
    add_column :subscriptions, :card_expiry_month, :string
    add_column :subscriptions, :card_brand, :string
    add_column :subscriptions, :payment_id, :string
  end
end
