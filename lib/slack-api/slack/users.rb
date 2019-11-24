require 'httparty'
module SlackAPI
  module Slack
    module Users
      def get_id(name:, workspace:)
        begin
          opts = {
            headers: { 'Content-Type': 'x-www-formencoded' },
            query: { token: token }
          }
          response = HTTParty.get("https://#{workspace}.slack.com/api/users.identity", opts)
          json = JSON.parse(response.body)
          if response.code == 200 and json[:error] == 'ok'
            return response[:user][:id]
          end
        rescue Exception => e
          puts "ERROR: Couldn't fetch identity: #{e}"
          return nil
        end
      end
    end
  end
end
