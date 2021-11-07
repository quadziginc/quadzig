class AddAccountAssociation < ActiveRecord::Migration[6.0]
  def change
    add_reference :aws_ec2_instances, :aws_account, foreign_key: true, type: :uuid
    add_reference :aws_subnets, :aws_account, foreign_key: true, type: :uuid
  end
end
