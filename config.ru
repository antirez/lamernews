$LOAD_PATH.unshift File.dirname(__FILE__)
require './app'
require './api'

use Lamernews::API

run Sinatra::Application
