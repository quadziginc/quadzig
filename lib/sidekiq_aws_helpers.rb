module SidekiqAwsHelpers
  def get_aws_iam_credentials(user_id, account_id)
    user = User.find(user_id)
    account = user.aws_accounts.find(account_id)

    sts = Aws::STS::Client.new(region: 'us-east-1')
    external_id = account.external_id
    role_session_name = "Quadzig-#{SecureRandom.hex(10)}"
    role_arn = account.iam_role_arn

    begin
      resp = sts.assume_role(
        external_id: external_id,
        role_arn: role_arn,
        role_session_name: role_session_name
      )
    # Initializing a large number of clients on a single Fargate Task
    # raises this error.
    # More details here - https://github.com/aws/amazon-ecs-agent/pull/1240
    rescue Aws::Errors::MissingCredentialsError
      return [nil, nil, nil]
    end

    access_key = resp.credentials.access_key_id
    secret_key = resp.credentials.secret_access_key
    session_token = resp.credentials.session_token

    return [access_key, secret_key, session_token]
  end

  def create_es_docs(records)
    records.each do |record|
      id = record[:id]
      routing_key = record[:routing_key]

      attributes = (record[:attributes]).merge({
        doc_as_upsert: true
      })

      # TODO: Convert this to bulk update
      EsClient.update({
        id: id,
        index: "cloud_resources",
        routing: routing_key, # Verified that missing routing key throws an exception
        body: attributes.to_json
      })
    end
  end

  def delete_es_docs(records)
    records.each do |record|
      id = record[:id]
      routing_key = record[:routing_key]

      begin
        EsClient.delete({
          id: id,
          index: "cloud_resources",
          routing: routing_key
        })
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        # Anything else to do?
        next
      end
    end
  end

  def enrich_attributes(attributes, account, user, resource_type, omit_list)
    meta_info = {
      rt: resource_type
    }

    account_info = {
      aws_account_id: account.account_id,
      aws_account_name: account.name,
      user_id: user.id
    }

    search_attributes = {
      doc: attributes.
            transform_keys { |key| key.to_s == "tag_list" ? :tags : key } # We want to provide a standard way for tag querying
            .except(*omit_list)
            .merge(
              account_info,
              meta_info
            )
    }

    return search_attributes
  end
end
