require 'httparty'
require 'slack-api/auth'
require 'slack-api/aws_helpers/api_gateway'
require 'slack-api/slack/api'
require 'uri'

module SlackAPI
  module Slack
    module Profile
      module Status
        def self.set!(event)
          param_map = {}
          %w[text emoji].each do |parameter|
            value = SlackAPI::AWSHelpers::APIGateway::Events.get_param(event: event,
                                                                       param: parameter)
            if value.nil? && (parameter == 'text')
              return SlackAPI::AWSHelpers::APIGateway.error(
                message: "Parameter required: #{parameter}"
              )
            end
            param_map[parameter] = value
          end

          # I should probably make an authenticated session a class that has
          # its token in it, but I'm tight af on time...so ugly it is!
          token_data = SlackAPI::Auth.get_slack_token(event: event)
          token = JSON.parse(token_data[:body])['token']
          unless SlackAPI::Slack::OAuth.token_valid?(token: token)
            return SlackAPI::AWSHelpers::APIGateway.unauthenticated(message: 'Unable to validate token.')
          end
          if SlackAPI::Slack::OAuth.token_expired?(token: token)
            return SlackAPI::AWSHelpers::APIGateway.unauthenticated(message: 'Token expired')
          end

          text = param_map['text']
          emoji = param_map['emoji']
          begin
            current_profile = get_current_profile(token: token)
            current_text = current_profile[:status_text]
            current_emoji = current_profile[:status_emoji]
            if (text == current_text) && (emoji == current_emoji)
              return SlackAPI::AWSHelpers::APIGateway.ok(additional_json: {
                                                           changed: {}
                                                         })
            end
            new_emoji = if emoji.nil?
                          current_emoji
                        else
                          emoji
                        end
            set_profile(token: token,
                        text: text,
                        emoji: new_emoji)
            SlackAPI::AWSHelpers::APIGateway.ok(
              additional_json: {
                changed: {
                  old: "#{current_profile[:status_emoji]} #{current_profile[:status_text]}",
                  new: "#{new_emoji} #{text}"
                }
              }
            )
          rescue Exception => e
            SlackAPI.logger.error "[#{SlackAPI::Slack::OAuth.scrubbed_token(token: token)}] Couldn't set profile: #{e} -> #{e.backtrace.join('\n')}]"
            SlackAPI::AWSHelpers::APIGateway.error(
              message: "Something weird happened while setting your profile: #{e}"
            )
          end
        end

        def self.get_current_profile(token:)
          response = SlackAPI::Slack::API.get_from(endpoint: 'users.profile.get',
                                                   token: token,
                                                   content_type: 'application/x-www-formencoded')
          json = JSON.parse(response.body, symbolize_names: true)
          if (response.code != 200) || !json[:ok]
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
          updated_profile = {
            status_text: text,
            status_emoji: emoji
          }
          response = SlackAPI::Slack::API.post_to(endpoint: 'users.profile.set',
                                                  token: token,
                                                  content_type: 'application/json',
                                                  params: {
                                                    profile: updated_profile.to_json
                                                  })
          json = JSON.parse(response.body, symbolize_names: true)
          if (response.code != 200) || !json[:ok]
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
