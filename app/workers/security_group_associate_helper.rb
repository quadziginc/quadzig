module SecurityGroupAssociateHelper
  private

  def store_security_groups(client:, resource:, account:, groups_ids:, region_code:)
    client.describe_security_groups(group_ids: groups_ids).each do |response|
      response.security_groups.each do |sg|
        vpc = account.aws_vpcs.find_by(vpc_id: sg.vpc_id)
        vpc.aws_security_groups.find_or_create_by(group_id: sg.group_id, aws_resource: resource).tap do |group|
          sg_attrs = sg.to_h
          sg_attrs.delete(:vpc_id)
          group.last_synced_at = Time.current
          group.region_code = region_code
          group.update(sg_attrs)
        end
      end
    end
  end

  def db_security_group_ids_for(db_instance)
    db_instance.vpc_security_groups.map { |groups| groups['vpc_security_group_id'] }
  end
end
