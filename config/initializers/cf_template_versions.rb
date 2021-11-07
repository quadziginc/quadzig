if ENV['ASSET_PRECOMPILE'].to_i == 0
  CfTemplateVersionsCreatorWorker.perform_async()
end