require 'faraday_middleware/aws_sigv4'

if ENV['ASSET_PRECOMPILE'].to_i == 0
  if Rails.env == "development"
    url = "http://#{ENV['SEARCH_ES_HOST']}:9200"
    EsClient = Elasticsearch::Client.new url: url, log: true
  else
    creds = (Aws::ECSCredentials.new).credentials
    url = "https://#{ENV['SEARCH_ES_HOST']}:443"

    EsClient = Elasticsearch::Client.new(url: url, log: true) do |f|
      f.request :aws_sigv4,
      credentials: creds,
      service: 'es',
      region: ENV['AWS_DEFAULT_REGION']
    end
  end

  index_settings = { number_of_shards: 1, number_of_replicas: 0 }
  settings = {
    settings: {
      index: index_settings
    },
    mappings: {
     _routing: {
        required: true 
      } 
    }
  }

  resource_types = [
    "cloud_resources"
  ]

  resource_types.each do |resource_type|
    unless EsClient.indices.exists? index: resource_type
      EsClient.indices.create(index: resource_type, body: settings)
    end
  end

  # IMPORTANT
  # TODO: Move this elsewhere?
  # EsClient.cluster.put_settings(body: {transient: { search: { allow_expensive_queries: false } } })
end