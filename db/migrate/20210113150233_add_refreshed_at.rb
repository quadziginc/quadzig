class AddRefreshedAt < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :refresh_started_at, :datetime
  end
end
