require 'httparty'

module SlackAPI
  module Slack
    module OAuth
=begin
      Retrieve an OAuth token for a given client ID.
      See: https://api.slack.com/docs/oauth
=end
      include HTTParty
      base_uri 'slack.com'
      def self.access(client_id:, client_secret:, code:, redirect_uri:)
        params = {
          client_id: client_id,
          client_secret: client_secret,
          code: code,
          redirect_uri: redirect_uri
        }
        get('/api/oauth.access', query: params)
      end
    end

=begin
=end
    module Users
      module Profile
        def self.set_profile
        end
      end
    end
  end
end
