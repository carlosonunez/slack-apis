require 'httparty'
require 'slack-api/slack/api'

module SlackAPI
  module Slack
    module Users
      def self.get_id(token:)
        begin
          response = SlackAPI::Slack::API.get_from(endpoint: 'users.identity',
                                                   content_type: 'application/x-www-formencoded',
                                                   token: token)
          json = JSON.parse(response.body, symbolize_names: true)
          if response.code == 200 and json[:status] == 'ok'
            return json[:user][:id]
          end
        rescue Exception => e
          puts "ERROR: Couldn't fetch identity: #{e}"
          return nil
        end
      end
    end
  end
end
