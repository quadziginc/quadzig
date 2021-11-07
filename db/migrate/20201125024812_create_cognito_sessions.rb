class CreateCognitoSessions < ActiveRecord::Migration[6.0]
  def change
    create_table :cognito_sessions, id: :uuid do |t|
      t.references :user, index: true, null: false, type: :uuid
      t.integer :expire_time, :null => false
      t.integer :issued_time, :null => false
      t.string :audience, :null => false
      t.text :refresh_token, :null => false

      t.timestamps
    end
  end
end
