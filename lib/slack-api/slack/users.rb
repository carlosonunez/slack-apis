# frozen_string_literal: true

require 'httparty'
require 'slack-api/slack/api'

module SlackAPI
  module Slack
    module Users
      def self.get_id(token:)
        response = SlackAPI::Slack::API.get_from(endpoint: 'users.identity',
                                                 content_type: 'application/x-www-form-urlencoded',
                                                 token: token)
        json = JSON.parse(response.body, symbolize_names: true)
        json[:user][:id] if (response.code == 200) && (json[:status] == 'ok')
      rescue Exception => e
        puts "ERROR: Couldn't fetch identity: #{e}"
        nil
      end
    end
  end
end
