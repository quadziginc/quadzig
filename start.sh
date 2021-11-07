#!/bin/sh

# https://github.com/rails/rails/issues/22092
# Running migration from multiple instances should be fine.
rake db:migrate
rake db:seed
rails s