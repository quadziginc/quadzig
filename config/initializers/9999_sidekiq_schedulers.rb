# TODO: !Important! Stagger this eventually
# TODO: Find a better way to schedule the workers(or verify that this is good enough)
# Sidekiq::Cron::Job.create(
#   name: 'ScheduledCidrClashCheckInitiatorWorkerFree',
#   cron: '*/30 * * * *',
#   class: 'ScheduledCidrClashCheckInitiatorWorker',
#   args: [:free]
# )

# Sidekiq::Cron::Job.create(
#   name: 'ScheduledCidrClashCheckInitiatorWorkerStartup',
#   cron: '*/5 * * * *',
#   class: 'ScheduledCidrClashCheckInitiatorWorker',
#   args: [:startup]
# )

# Sidekiq::Cron::Job.create(
#   name: 'ScheduledCidrClashCheckInitiatorWorkerEnterprise',
#   cron: '*/2 * * * *',
#   class: 'ScheduledCidrClashCheckInitiatorWorker',
#   args: [:enterprise]
# )

# if ENV['ASSET_PRECOMPILE'].to_i == 0
#   Sidekiq::Cron::Job.create(
#     name: 'ScheduledDailyBillingUpdateWorker',
#     cron: '1 0 * * *',
#     class: 'ScheduledDailyBillingUpdateWorker'
#   )
# end

if ENV['ASSET_PRECOMPILE'].to_i == 0
  Sidekiq::Cron::Job.create(
    name: 'ClearRefreshTimerWorker',
    cron: '*/5 * * * *',
    class: 'ClearRefreshTimerWorker'
  )
end

if ENV['ASSET_PRECOMPILE'].to_i == 0
  Sidekiq::Cron::Job.create(
    name: 'AccountCreationSignalWorker',
    cron: '*/1 * * * *',
    class: 'AccountCreationSignalWorker'
  )
end
