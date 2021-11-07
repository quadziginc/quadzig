class AddLoadBalancer < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_load_balancers, id: :uuid do |t|
      t.string :load_balancer_arn
      t.string :dns_name
      t.datetime :created_time
      t.string :load_balancer_name
      t.string :scheme
      t.string :vpc_id, index: true
      t.string :state
      t.string :lb_type
      t.json :availability_zones
      t.json :security_groups

      t.string :region_code
      t.json :tags
      t.belongs_to :aws_account, type: :uuid
      t.timestamps
    end
  end
end
