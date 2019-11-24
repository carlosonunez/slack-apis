require 'httparty'

module SlackAPI
  module Slack
    module API
      # Issues a GET request against a Slack API method.
      def self.get_from(endpoint:, token: nil, params:, content_type: 'application/json')
        include HTTParty
        base_uri 'slack.com'
        params[:token] = token if !token.nil?
        get("/api/#{endpoint}", query: params, options: {
          headers: { 'Content-Type': content_type }
        })
      end

      def self.post_to(endpoint:, token: nil, params:, body:, content_type: 'application/x-www-urlencoded')
        include HTTParty
        base_uri 'slack.com'
        params[:token] = token if !token.nil?
        post("/api/#{endpoint}", query: params, body: body, options: {
          headers: { 'Content-Type': content_type }
        })
      end
    end
  end
end

