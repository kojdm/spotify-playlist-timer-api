require 'rubygems'
require 'bundler'

Bundler.require 
$stdout.sync = true

Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDIS_URL"] }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV["REDIS_URL"] }
end

require_relative './server'
run Sinatra::Application
