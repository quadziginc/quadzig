class AddTagsToSubnets < ActiveRecord::Migration[6.0]
  def change
    add_column :aws_subnets, :tags, :json
  end
end
