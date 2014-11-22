require_relative '../app'
require 'rspec'
require 'rack/test'

set :environment, :test

RSpec.configure do |config|
  config.before :each do
    uri = URI.parse RedisURL
    Redis.new(host: uri.host, port: uri.port, password: uri.password).flushdb
  end
end
