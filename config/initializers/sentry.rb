unless Rails.env == 'development'
  Sentry.init do |config|
    config.before_send = lambda do |event, hint|
      # skip ZeroDivisionError exceptions
      # note: hint[:exception] would be a String if you use async callback
      if hint[:exception].is_a?(Elasticsearch::Transport::Transport::Errors::Forbidden)
        nil
      else
        event
      end
    end

    config.dsn = ENV['SENTRY_DSN']
    config.breadcrumbs_logger = [:sentry_logger, :active_support_logger]

    config.traces_sampler = lambda do |context|
      transaction = context[:transaction_context]
      if transaction[:name].match?("health_check")
        0.0
      else
        0.2
      end
    end
  end
end
