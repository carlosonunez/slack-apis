require 'httparty'
require 'slack-api/auth'
require 'slack-api/aws_helpers/api_gateway'
require 'slack-api/slack/api'

module SlackAPI
  module Slack
    module Profile
      module Status
        def self.set!(event)
          param_map = {}
          %w(text emoji).each do |parameter|
            value = SlackAPI::AWSHelpers::APIGateway::Events.get_param(event: event,
                                                                       param: parameter)
            if value.nil? and parameter == 'text'
              return SlackAPI::AWSHelpers::APIGateway.error(
                message: "Parameter required: #{parameter}")
            end
            param_map[parameter] = value
          end

          # I should probably make an authenticated session a class that has
          # its token in it, but I'm tight af on time...so ugly it is!
          token_data = SlackAPI::Auth.get_slack_token(event: event)
          token = JSON.parse(token_data[:body])['token']
          if SlackAPI::Slack::OAuth.token_expired?(token: token)
            return SlackAPI::AWSHelpers::APIGateway.unauthenticated(message: 'Token expired')
          end
          text = param_map['text']
          emoji = param_map['emoji']
          begin
            current_profile = self.get_current_profile(token: token)
            if emoji.nil?
              new_emoji = current_profile[:status_emoji]
            else
              new_emoji = emoji
            end
            self.set_profile(token: token,
                             text: text,
                             emoji: new_emoji)
            SlackAPI::AWSHelpers::APIGateway.ok(
              additional_json: {
                changed: {
                  old: "#{current_profile[:status_emoji]} #{current_profile[:status_text]}",
                  new: "#{new_emoji} #{text}"
                }
              })
          rescue Exception => e
            return SlackAPI::AWSHelpers::APIGateway.error(
              message: "Something weird happened while setting your profile: #{e}")
          end
        end

        private
        def self.get_current_profile(token:)
          response = SlackAPI::Slack::API.get_from(endpoint: 'users.profile.get',
                                                   token: token,
                                                   content_type: 'application/x-www-formencoded')
          json = JSON.parse(response.body, symbolize_names: true)
          if response.code != 200 or !json[:ok]
            case json[:error]
            when 'not_authed'
              raise 'Not authenticated.'
            when 'user_not_found'
              raise 'User not found.'
            when 'invalid_auth'
              raise 'Token not valid.'
            else
              raise "Some other error: #{json[:error]}"
            end
          end
          json[:profile]
        end

        def self.set_profile(token:, text:, emoji:)
          response = SlackAPI::Slack::API.post_to(endpoint: 'users.profile.set',
                                                  token: token,
                                                  content_type: 'application/json',
                                                  params: {
                                                    profile: {
                                                      status_text: text,
                                                      status_emoji: emoji
                                                    }.to_json
                                                  })
          json = JSON.parse(response.body, symbolize_names: true)
          if response.code != 200 or !json[:ok]
            case json[:error]
            when 'not_authed'
              raise 'Not authenticated.'
            when 'user_not_found'
              raise 'User not found.'
            when 'invalid_auth'
              raise 'Token not valid.'
            else
              raise "Some other error: #{json[:error]}"
            end
          end
          json[:profile]
        end
      end
    end
  end
end
