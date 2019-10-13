require 'json'

module SlackAPI
  module AWSHelpers
    class APIGateway
      def self.return_200(body:, json: nil)
        raise "JSON should be a hash" if !json.nil? and json.class != Hash
        default_response = { message: body }
        {
          :statusCode => 200,
          :body => json || default_response.to_json
        }
      end
    end
  end
end
