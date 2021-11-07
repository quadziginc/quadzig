class AddAzsToRegion < ActiveRecord::Migration[6.0]
  def change
    add_column :aws_regions, :availability_zones, :string, array: true, default: []
  end
end
