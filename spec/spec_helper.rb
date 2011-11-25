require 'simplecov'
SimpleCov.start

# Load Sinatra application
require File.join(File.dirname(__FILE__), '..', 'app.rb')

require 'rspec'
require 'rack/test'
require 'nokogiri'

set :environment, :test
set :run, false
set :raise_errors, true
set :logging, false

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

def app
  @app ||= Sinatra::Application
end
