require 'net/http'

module Helpers
  module Integration
    def self.get(endpoint:)
      raise "Define the DNS_DOMAIN that will host Slack API" if ENV['DNS_DOMAIN'].nil?

      Net::HTTP.get(URI('https://' + ENV['DNS_DOMAIN'] + endpoint))
    end
  end
end

