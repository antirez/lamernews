require_relative '../app'
require 'rspec'
require 'rack/test'
require 'timecop'

set :environment, :test

RSpec.configure do |config|
  config.before :each do
    uri = URI.parse RedisURL
    $r = Redis.new(host: uri.host, port: uri.port, password: uri.password)
    $r.flushdb
  end
end
