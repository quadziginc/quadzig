class CreateResourceGroups < ActiveRecord::Migration[6.0]
  def change
    create_table :resource_groups, id: :uuid do |t|
      t.string :name
      t.json :accounts, default: {}
      t.json :display_config, default: {}
      t.boolean :default, default: false
      t.belongs_to :user, type: :uuid

      t.timestamps
    end
  end
end
