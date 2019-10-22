require 'httparty'

module SlackAPI
  module Slack
    module API
      # Issues a GET request against a Slack API method.
      def self.get_from(endpoint:, params:)
        include HTTParty
        base_uri 'slack.com'

        get(endpoint, query: params)
      end
    end
  end
end

