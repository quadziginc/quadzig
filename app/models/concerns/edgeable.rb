module Edgeable
  extend ActiveSupport::Concern

  included do
    scope :with_source_edges, -> { where('ip_permissions::text LIKE ?', '%group_id%') }
  end

  def source_edges
    ip_permissions.flat_map { |ingress| ingress['user_id_group_pairs'].map { |user_group| user_group['group_id'] } }
  end

  def ingress_count
    count_for(ip_permissions)
  end

  def egress_count
    count_for(ip_permissions_egress)
  end

  private

  def count_for(permissions)
    permissions.sum { |permission| permission['user_id_group_pairs'].count }
  end
end
