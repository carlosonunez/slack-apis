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
        SlackAPI::Slack::API.get_from(endpoint: '/api/oauth.access', params: params)
      end
    end
  end
end

