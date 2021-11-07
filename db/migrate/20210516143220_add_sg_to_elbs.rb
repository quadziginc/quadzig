class AddSgToElbs < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_elb_security_groups, id: :uuid do |t|
      t.string :description
      t.string :group_name
      t.json :ip_permissions
      t.string :owner_id
      t.string :group_id
      t.json :ip_permissions_egress
      t.string :vpc_id
      t.string :region_code
      t.datetime :last_updated_at

      t.belongs_to :aws_elb, type: :uuid
      t.timestamps
    end
  end
end
