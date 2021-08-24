# frozen_string_literal: true

require 'httparty'

module SlackAPI
  module Slack
    module API
      # Issues a GET request against a Slack API method.
      def self.get_from(endpoint:, token: nil, params: {}, content_type: 'application/json')
        headers = { 'Content-Type' => content_type }
        headers['Authorization'] = "Bearer #{token}" unless token.nil?
        scrubbed_token = SlackAPI::Slack::OAuth.scrubbed_token(token: token)
        SlackAPI.logger.debug("[#{scrubbed_token}] GET #{endpoint} with #{params}\n")
        debug_output_stream = ($stdout if SlackAPI.logger.debug?)
        HTTParty.get("https://slack.com/api/#{endpoint}",
                     headers: headers,
                     params: nil,
                     debug_output: debug_output_stream)
      end

      # HTTParty always URI-encoded parameters and body payloads. Turning it off requires overriding
      # a built-in method, which I'd prefer not to do.
      # Instead, I'll make x-www-url-formencded the default content-type.
      def self.post_to(endpoint:, token: nil, params: {}, body: nil, content_type: 'application/x-www-form-urlencoded')
        headers = { 'Content-Type' => content_type }
        headers['Authorization'] = "Bearer #{token}" unless token.nil?
        scrubbed_token = SlackAPI::Slack::OAuth.scrubbed_token(token: token)
        debug_output_stream = ($stdout if SlackAPI.logger.debug?)
        SlackAPI.logger.debug("[#{scrubbed_token}] POST #{endpoint} -> #{body} with params #{params}")
        HTTParty.post("https://slack.com/api/#{endpoint}",
                      query: params,
                      body: body,
                      headers: headers,
                      debug_output: debug_output_stream)
      end
    end
  end
end
