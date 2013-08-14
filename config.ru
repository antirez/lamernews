$LOAD_PATH.unshift File.dirname(__FILE__)
require './app'
require './api'


run Sinatra::Application
