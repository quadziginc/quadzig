class AwsCfTemplateVersioning < ActiveRecord::Migration[6.0]
  def change
    create_table :cf_template_versions, id: :uuid do |t|
      t.string :cf_link, null: false, index: { unique: true }
      t.string :version, null: false, index: { unique: true }
      t.boolean :is_latest, default: false

      t.timestamps
    end

    add_reference :aws_accounts, :cf_template_version, type: :uuid
  end
end
