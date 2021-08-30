# frozen_string_literal: true

require 'httparty'
require 'slack-api/auth'
require 'slack-api/aws_helpers/api_gateway'
require 'slack-api/slack/api'
require 'uri'
require 'time'

module SlackAPI
  module Slack
    module Profile
      # Methods for manipulating a user's status through their profile.
      module Status
        def self.get_text_and_emoji(event)
          {
            text: SlackAPI::AWSHelpers::APIGateway::Events.get_param(event: event, param: 'text'),
            emoji: SlackAPI::AWSHelpers::APIGateway::Events.get_param(event: event, param: 'emoji')
          }
        end

        def self.get!(event)
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

          begin
            current_profile = get_current_profile(token: token)
            SlackAPI::AWSHelpers::APIGateway.ok(
              additional_json: {
                data: {
                  status_text: current_profile[:status_text],
                  status_emoji: current_profile[:status_emoji],
                  status_expiration: current_profile[:status_expiration]
                }
              }
            )
          rescue Exception => e
            SlackAPI.logger.error "[#{SlackAPI::Slack::OAuth.scrubbed_token(token: token)}] Couldn't get profile: #{e} -> #{e.backtrace.join('\n')}]"
            SlackAPI::AWSHelpers::APIGateway.error(
              message: "Something weird happened while getting your profile: #{e}"
            )
          end
        end

        def self.set!(event)
          param_map = {}
          %w[text emoji expiration].each do |parameter|
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
          expiration_unix = param_map['expiration']
          begin
            current_profile = get_current_profile(token: token)
            current_text = current_profile[:status_text]
            current_emoji = current_profile[:status_emoji]
            current_expiration = current_profile[:status_expiration]
            SlackAPI.logger.debug("Comparing [#{text} -> #{emoji} -> #{expiration_unix}] with \
                                  [#{current_text} -> #{current_emoji} -> #{current_expiration}]")
            if (text == current_text) &&
               (emoji == current_emoji) &&
               (expiration_unix == current_expiration)
              return SlackAPI::AWSHelpers::APIGateway.ok(
                additional_json: {
                  changed: {}
                }
              )
            end
            new_emoji = if emoji.nil?
                          current_emoji
                        else
                          emoji
                        end
            set_profile(token: token,
                        text: text,
                        emoji: new_emoji,
                        expiration: expiration_unix)
            payload = {
              old: "#{current_profile[:status_emoji]} #{current_profile[:status_text]}",
              new: "#{new_emoji} #{text}"
            }
            payload[:expires_on] = Time.at(expiration_unix.to_i).rfc2822 unless expiration_unix.nil?
            SlackAPI::AWSHelpers::APIGateway.ok(
              additional_json: {
                changed: payload
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
                                                   content_type: 'application/x-www-form-urlencoded')
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

        def self.set_profile(token:, text:, emoji:, expiration: nil)
          updated_profile = {
            status_text: text,
            status_emoji: emoji
          }
          updated_profile[:status_expiration] = expiration unless expiration.nil?
          response = SlackAPI::Slack::API.post_to(endpoint: 'users.profile.set',
                                                  token: token,
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
