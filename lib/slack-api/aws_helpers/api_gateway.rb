require 'json'

module SlackAPI
  module AWSHelpers
    class APIGateway
      def self.return_200(body:)
        {
          :statusCode => 200,
          :body => body
        }.to_json
      end
    end
  end
end
