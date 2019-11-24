require 'slack-api/aws_helpers/api_gateway'
require 'slack-api/auth'

module SlackAPI
  module Slack
    module Profile
      module Status
        def self.set!(event)
          param_map = {}
          %w(user workspace).each do |required_parameter|
            value = SlackAPI::AWSHelpers::APIGateway::Events.get_param(event: event,
                                                                       param: required_parameter)
            if value.nil?
              return SlackAPI::AWSHelpers::APIGateway.error(
                message: "Parameter required: #{required_parameter}")
            end
            param_map[required_parameter] = value
          end
          
          token = SlackAPI::Auth.get_slack_token(event: event)
          if SlackAPI::Slack::OAuth.token_expired? token
            SlackAPI::AWSHelpers::APIGateway.unauthenticated(message: 'Token expired')
          end
        end
      end
    end
  end
end
