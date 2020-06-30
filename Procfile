web: bundle exec thin -t 60 start --threaded -R config.ru -e $RACK_ENV -p ${PORT:-5000}
worker: bundle exec sidekiq -c 5 -v
