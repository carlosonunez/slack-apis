require 'rspec'
require 'slack-api'
require 'httparty'
require 'aws-sdk-dynamodb'
require 'capybara'
require 'capybara/dsl'
require 'selenium-webdriver'
Dir.glob('/app/spec/helpers/**/*.rb') do |file|
  require_relative file
end

# Test setup and teardown is done entirely through docker-compose to
# reduce the number of  moving parts. Since docker-compose runs all of its dependent services
# in parallel, we need to manually synchronize the state of our tests and
# manually await certain data becoming available.
RSpec.configure do |config|
  config.include Capybara::DSL, :integration => true
  config.before(:all, :integration => true) do
    ['SELENIUM_HOST', 'SELENIUM_PORT'].each do |required_selenium_env_var|
      raise "Please set #{required_selenium_env_var}" if ENV[required_selenium_env_var].nil?
    end

    $api_gateway_url = ENV['API_GATEWAY_URL'] || Helpers::Integration::HTTP.get_endpoint
    raise "Please define API_GATEWAY_URL as an environment variable or \
run 'docker-compose run --rm integration-setup'" \
      if $api_gateway_url.nil? or $api_gateway_url.empty?

    $test_api_key =
      Helpers::Integration::SharedSecrets.read_secret(secret_name: 'api_key') ||
        raise('Please create the "api_key" secret.')

    Capybara.run_server = false
    Capybara.register_driver :selenium do |app|
      Capybara::Selenium::Driver.new(
        app,
        browser: :remote,
        url: "http://#{ENV['SELENIUM_HOST']}:#{ENV['SELENIUM_PORT']}/wd/hub",
        desired_capabilities: Selenium::WebDriver::Remote::Capabilities.chrome(
          "chromeOptions" => {
            "args" => ['--no-default-browser-check']
          }
        )
      )
    end
    Capybara.default_driver = :selenium
  end
end
