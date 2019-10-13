require 'net/http'

module Helpers
  module Integration
    module HTTP
      def self.get_endpoint
        seconds_to_wait = ENV['API_GATEWAY_URL_FETCH_TIMEOUT'] || 60
        puts "Waiting up to #{seconds_to_wait} seconds for endpoint to become available..."
        attempts = 1
        while attempts <= seconds_to_wait
          begin
            return Helpers::Integration::SharedSecrets.read_secret secret_name: 'endpoint_name'
          rescue
            attempts += 1
            sleep 1
          end
        end
        raise "Secret 'endpoint_name' not found."
      end
    end
  end
end

