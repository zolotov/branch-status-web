$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'sinatra'
require 'branch-status-web'

run Sinatra::Application
