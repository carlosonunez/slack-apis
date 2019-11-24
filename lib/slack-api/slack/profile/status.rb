require 'slack-api/aws_helpers/api_gateway'

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
          return nil
        end
      end
    end
  end
end
