APP_REDIS_POOL = ConnectionPool.new(size: 52) { Redis.new(url: ENV['REDIS_URI']) }
