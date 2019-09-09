require 'json'
require 'slack-api/aws_helpers/api_gateway'

module SlackAPI
  class Health
    def self.ping
      AWSHelpers::APIGateway.return_200 body: "sup dawg"
    end
  end
end
