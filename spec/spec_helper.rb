require 'rspec'
require 'slack-api'
Dir.glob('/app/spec/helpers/**/*.rb') do |file|
  require_relative file
end
