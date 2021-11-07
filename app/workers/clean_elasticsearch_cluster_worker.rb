class CleanElasticsearchClusterWorker
  include Sidekiq::Worker

  def perform(ids, user_id)
    # TODO: Make this a bulk operation
    ids.each do |id|
      begin
        EsClient.delete({
          id: id,
          index: "cloud_resources",
          routing: user_id
        })
      rescue
        # TODO: Log here?
      end
    end
  end
end