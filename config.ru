require 'rubygems'
require 'bundler'

Bundler.require 
$stdout.sync = true

require_relative './server'
run Sinatra::Application
