web:                                  bin/rails server -p $PORT -e $RAILS_ENV
worker: env DB_POOL=$SIDEKIQ_DB_POOL  sidekiq start -c $SIDEKIQ_CONCURRENCY -C config/sidekiq.yml
clock:  env DB_POOL=1                 bundle exec clockwork lib/clock.rb
