require 'logger'
require 'slack-api/health'
require 'slack-api/auth'
require 'slack-api/slack/oauth'
require 'slack-api/slack/users'
require 'slack-api/slack/profile/status'

module SlackAPI
  @logger = Logger.new(STDOUT)
  @logger.level = ENV['LOG_LEVEL'] || Logger::WARN
  def self.logger
    @logger
  end
end
