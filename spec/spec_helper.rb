require 'rspec'
require 'slack-api'
require 'httparty'
require 'aws-sdk-dynamodb'
Dir.glob('/app/spec/helpers/**/*.rb') do |file|
  require_relative file
end

# Test setup and teardown is done entirely through docker-compose to
# reduce the number of  moving parts. Since docker-compose runs all of its dependent services
# in parallel, we need to manually synchronize the state of our tests and
# manually await certain data becoming available.
RSpec.configure do |config|
  config.before(:all, :integration => true) do
    $api_gateway_url = ENV['API_GATEWAY_URL'] || Helpers::Integration::HTTP.get_endpoint
    raise "Please define API_GATEWAY_URL as an environment variable or \
run 'docker-compose run --rm integration-setup'" \
      if $api_gateway_url.nil? or $api_gateway_url.empty?
  end
end
