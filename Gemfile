source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.2'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 7.0.0'
# Use Puma as the app server
gem 'puma', '~> 6.0'
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
gem 'shakapacker', '~> 6.5.2'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.4', require: false

gem 'sidekiq'
gem 'aws-sdk', '~> 3'
gem "sidekiq-cron", "~> 1.1"
gem 'redis'
gem 'dotenv-rails'
gem 'excon', '~> 0.71.0'
gem 'json-jwt', '~> 1.16.0'
gem 'pagy', '~> 6.2'
gem 'pg', '~> 1.5.4'
gem 'stripe'
gem "sentry-ruby"
gem "sentry-rails"
gem "sentry-sidekiq"

# https://github.com/rails/rails/issues/41757#issuecomment-808024283
# sentry depends on this gem and the legendary author has pulled the gem out of the rubygems due to GPL
gem 'mimemagic', github: 'mimemagicrb/mimemagic', ref: '01f92d86d15d85cfd0f20dabd025dcbd36a8a60f'

gem 'lograge', '~> 0.11.2'
gem 'rubyzip', '~> 2.3.0'
gem 'elasticsearch', '~> 8.11.0'
gem 'grape-entity', '~> 0.9.0'
gem 'faraday_middleware-aws-sigv4', '~> 1.0.1'
gem 'elasticsearch-dsl'
gem 'parslet'
gem 'rqrcode'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'brakeman'
  gem "letter_opener"
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 4.1.0'
  # Display performance information such as SQL time and flame graphs for each request in your browser.
  # Can be configured to work on production as well see: https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md
  gem 'rack-mini-profiler', '~> 3.0'
  gem 'listen', '~> 3.8'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'pry'
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 3.26'
  gem 'selenium-webdriver'
  # Easy installation and use of web drivers to run system tests with browsers
  gem 'webdrivers'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', '~>1.2023.3'
