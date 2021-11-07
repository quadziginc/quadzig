if ENV['ASSET_PRECOMPILE'].to_i == 0
  # TODO: Eventually, separate the into 2 redis clusters
  # One for general redis ops & one for sidekiq

  # TODO: Check if Global is the best way to do this
  # Should be sidekiq pool size + 2
  # Should probably not hardcode this.
  # TODO: change to env var later.
  REDIS_POOL = ConnectionPool.new(size: 52) { Redis.new(url: ENV['REDIS_URI']) }
  Sidekiq.configure_server do |config|
    config.redis = REDIS_POOL
    config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new
  end

  Sidekiq.configure_client do |config|
    config.redis = REDIS_POOL
  end
end