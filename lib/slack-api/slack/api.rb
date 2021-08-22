require 'httparty'

module SlackAPI
  module Slack
    module API
      # Issues a GET request against a Slack API method.
      def self.get_from(endpoint:, token: nil, params: {}, content_type: 'application/json')
        headers = { 'Content-Type' => content_type }
        headers['Authorization'] = "Bearer #{token}" unless token.nil?
        if params.empty?
          HTTParty.get("https://slack.com/api/#{endpoint}", headers: headers)
        else
          HTTParty.get("https://slack.com/api/#{endpoint}", headers: headers, query: params)
        end
      end

      def self.post_to(endpoint:, token: nil, params: {}, body: nil, content_type: 'application/x-www-formencoded')
        headers = { 'Content-Type' => content_type }
        headers['Authorization'] = "Bearer #{token}" unless token.nil?
        if params.empty?
          HTTParty.post("https://slack.com/api/#{endpoint}", body: body, headers: headers)
        else
          HTTParty.post("https://slack.com/api/#{endpoint}", query: params, body: body, headers: headers)
        end
      end
    end
  end
end

