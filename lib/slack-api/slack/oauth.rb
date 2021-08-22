require 'slack-api/slack/api'

module SlackAPI
  module Slack
    module OAuth
      # Retrieve an OAuth token from a given code and client ID/secret.
      def self.access(client_id:, client_secret:, code:, redirect_uri:)
        params = {
          client_id: client_id,
          client_secret: client_secret,
          code: code,
          redirect_uri: redirect_uri
        }
        SlackAPI::Slack::API.post_to(endpoint: 'oauth.access',
                                     content_type: 'application/x-www-formencoded',
                                     params: params)
      end

      def self.token_valid?(token:)
        response = SlackAPI::Slack::API.get_from(endpoint: 'auth.test', token: token)
        json = JSON.parse(response.body, symbolize_names: true)
        if not json.has_key?(:ok) or (!json[:ok] and json[:error] != 'invalid_auth')
          SlackAPI.logger.warn("Token ending in #{scrubbed_token(token)} is invalid: #{json}")
          false
        end
        true
      end

      def self.token_expired?(token:)
        response = SlackAPI::Slack::API.get_from(endpoint: 'auth.test', token: token)
        json = JSON.parse(response.body, symbolize_names: true)
        !json[:ok] and json[:error] == 'invalid_auth'
      end

      def self.scrubbed_token(token:)
        token[0..7]
      end
    end
  end
end

