class ResourceGroupCreationWorker
  include Sidekiq::Worker

  def perform
    User.all.each do |user|
      rg = user.resource_groups.where(default: true).first
      if rg.nil?
        user.resource_groups.create(default: true, name: 'Default')
      end

      if user.resource_groups.where(default: true).count > 1
        user.resource_groups.where(default: true).last.destroy!
      end
    end
  end
end