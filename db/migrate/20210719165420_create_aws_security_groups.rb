class CreateAwsSecurityGroups < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_security_groups, id: :uuid do |t|
      t.belongs_to :aws_vpc, type: :uuid
      t.belongs_to :aws_resource, polymorphic: true, type: :uuid,
                                  index: { name: :index_on_aws_resource_type_and_aws_resource_id }
      t.string :region_code
      t.string :description
      t.string :group_name
      t.json :ip_permissions
      t.string :owner_id
      t.string :group_id
      t.json :ip_permissions_egress
      t.json :tags

      t.timestamps
    end

    add_index(:aws_security_groups, :region_code)
  end
end
