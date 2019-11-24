require 'httparty'
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
          if SlackAPI::Slack::OAuth.token_expired?
            return SlackAPI::AWSHelpers::APIGateway.error(message: 'Token expired')
          end
          user = param_map['user']
          user_id = SlackAPI::Slack::Users.get_id(name: user,
                                                  token: token,
                                                  workspace: workspace)
          if user_id.nil?
            return SlackAPI::AWSHelpers::APIGateway.error(
              message: "User not found: #{user}")
          end
          workspace = param_map['workspace']
          text = param_map['text']
          emoji = param_map['emoji']
          begin
            current_profile = self.get_current_profile(user_id: user_id,
                                                       workspace: workspace)
            if emoji.nil?
              new_emoji = current_profile[:status_emoji]
            else
              new_emoji = emoji
            end
            self.set_profile(user_id: user_id,
                             workspace: workspace,
                             text: text,
                             emoji: new_emoji)
            SlackAPI::AWSHelpers::APIGateway.ok(
              additional_json: {
                changed: {
                  old_status: "#{current_profile[:status_emoji]} #{current_profile[:status_text]}",
                  new_status: "#{new_emoji} #{text}"
                }
              })
          rescue Exception => e
            return SlackAPI::AWSHelpers::APIGateway.error(
              message: "Something weird happened: #{e}")
          end
        end

        private
        def self.get_current_profile(token:, workspace:, user_id:)
          slack_url = "https://#{workspace}.slack.com/api/users.profile.get"
          opts = {
            headers: { 'Content-Type': 'application/x-www-formencoded' },
            query: {
              token: token,
              user: user_id
            }
          }
          response = HTTParty.get(slack_url, opts)
          json = JSON.parse(response.body)
          if response.code != 200 or !json[:ok]
            case json[:error]
            when 'not_authed'
              raise Exception('Not authenticated.')
            when 'user_not_found'
              raise Exception('User not found.')
            else
              raise Exception("Some other error: #{json[:error]}")
            end
          end
          json[:profile]
        end
      end
    end
  end
end
