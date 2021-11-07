class AddAwsRegions < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_regions, id: :uuid do |t|
      t.string :full_name, null: false
      t.string :region_code, null: false
      t.timestamps
    end
  end
end
