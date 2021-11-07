class AddUsersnapId < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :usersnap_id, :string, index: true
  end
end
