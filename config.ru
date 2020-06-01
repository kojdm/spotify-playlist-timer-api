require 'rubygems'
require 'bundler'

Bundler.require 

require_relative './server'
run Sinatra::Application
