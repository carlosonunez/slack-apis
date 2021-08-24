# frozen_string_literal: true

require 'aws-sdk-dynamodb'
require 'slack-api/aws_helpers/api_gateway'
require 'slack-api/slack'
require 'logger'
require 'securerandom'
require 'dynamoid'

module SlackAPI
  module Auth
    class SlackToken
      Dynamoid.configure do |config|
        config.namespace = "slack_auth_#{ENV['ENVIRONMENT'].downcase}"
        config.logger.level = Logger::FATAL
      end

      include Dynamoid::Document
      table name: :tokens, key: :access_key, read_capacity: 2, write_capacity: 2
      field :access_key
      field :slack_token
    end

    class SlackAuthState
      Dynamoid.configure do |config|
        config.namespace = "slack_auth_state_#{ENV['ENVIRONMENT'].downcase}"
        config.logger.level = Logger::FATAL
      end

      include Dynamoid::Document
      table name: :state_associations, key: :state_id, read_capacity: 2, write_capacity: 2
      field :access_key
      field :state_id
    end

    #     Handle Slack OAuth callbacks.
    def self.handle_callback(event)
      unless configure_aws!
        return SlackAPI::AWSHelpers::APIGateway.error(
          message: 'Please set APP_AWS_ACCESS_KEY and APP_AWS_SECRET_KEY'
        )
      end
      parameters = event['queryStringParameters']
      code = parameters['code']
      state_id = parameters['state']
      error = parameters['error']
      if !error.nil?
        SlackAPI::AWSHelpers::APIGateway.unauthenticated(
          message: 'User denied access to this app.'
        )
      elsif code.nil? && state_id.nil?
        SlackAPI::AWSHelpers::APIGateway.error(
          message: "Slack didn't send a code or state_id upon calling back."
        )
      else
        callback_url = "https://#{SlackAPI::AWSHelpers::APIGateway.get_endpoint(event)}#{event['requestContext']['path']}"
        token_response = SlackAPI::Slack::OAuth.access(client_id: ENV['SLACK_APP_CLIENT_ID'],
                                                       client_secret: ENV['SLACK_APP_CLIENT_SECRET'],
                                                       redirect_uri: callback_url,
                                                       code: code)
        if token_response.body.nil?
          return SlackAPI::AWSHelpers::APIGateway.error(
            message: 'Unable to get Slack token.'
          )
        end
        token_response_json = JSON.parse(token_response.body)
        if !token_response_json['ok'].nil? && !token_response_json['ok']
          return SlackAPI::AWSHelpers::APIGateway.unauthenticated(
            message: "Token request failed: #{token_response_json['error']}"
          )
        end
        token = token_response_json['access_token']
        access_key_from_state = get_access_key_from_state(state_id: state_id)
        if access_key_from_state.nil?
          return SlackAPI::AWSHelpers::APIGateway.error(
            message: "No access key exists for this state ID: #{state_id}"
          )
        end
        if put_slack_token(access_key: access_key_from_state, slack_token: token)
          SlackAPI::AWSHelpers::APIGateway.ok
        else
          SlackAPI::AWSHelpers::APIGateway.error(message: 'Unable to save Slack token.')
        end
      end
    end

    #     Provide a first step for the authentication flow.
    def self.begin_authentication_flow(event, client_id:)
      unless configure_aws!
        return SlackAPI::AWSHelpers::APIGateway.error(
          message: 'Please set APP_AWS_ACCESS_KEY and APP_AWS_SECRET_KEY'
        )
      end
      if !reauthenticate?(event: event) && has_token?(event: event)
        return SlackAPI::AWSHelpers::APIGateway.ok(message: 'You already have a token.')
      end

      scopes_csv = ENV['SLACK_APP_CLIENT_SCOPES'] || 'users.profile:read,users.profile:write'
      redirect_uri = "https://#{SlackAPI::AWSHelpers::APIGateway.get_endpoint(event)}/callback"
      workspace = get_workspace(event)
      state_id = generate_state_id
      workspace_url = if workspace.nil?
                        'slack.com'
                      else
                        "#{workspace}.slack.com"
                      end
      slack_authorization_uri = [
        "https://#{workspace_url}/oauth/authorize?client_id=#{client_id}",
        "scope=#{scopes_csv}",
        "redirect_uri=#{redirect_uri}",
        "state=#{state_id}"
      ].join '&'
      message = "You will need to authenticate into Slack first; click on or \
copy/paste this URL to get started: #{slack_authorization_uri}"
      unless associate_access_key_to_state_id!(event: event,
                                               state_id: state_id)
        return SlackAPI::AWSHelpers::APIGateway.error(
          message: "Couldn't map state to access key."
        )
      end
      SlackAPI::AWSHelpers::APIGateway.ok(message: message)
    end

    # Retrives a Slack OAuth token from a API Gateway key
    def self.get_slack_token(event:)
      unless configure_aws!
        return SlackAPI::AWSHelpers::APIGateway.error(
          message: 'Please set APP_AWS_ACCESS_KEY and APP_AWS_SECRET_KEY'
        )
      end
      access_key = get_access_key_from_event(event)
      return SlackAPI::AWSHelpers::APIGateway.error(message: 'Access key missing.') if access_key.nil?

      slack_token = get_slack_token_from_access_key(access_key)
      if slack_token.nil?
        return SlackAPI::AWSHelpers::APIGateway.not_found(
          message: 'No token exists for this access key.'
        )
      end
      SlackAPI::AWSHelpers::APIGateway.ok(
        additional_json: { token: slack_token }
      )
    end

    def self.get_workspace(event)
      event['queryStringParameters']['workspace']
    rescue StandardError
      nil
    end

    def self.generate_state_id
      SecureRandom.hex
    end

    def self.get_access_key_from_event(event)
      event['requestContext']['identity']['apiKey']
    end

    def self.get_slack_token_from_access_key(access_key)
      results = SlackToken.where(access_key: access_key)
      return nil if results.count.zero?

      results.first.slack_token
    rescue Aws::DynamoDB::Errors::ResourceNotFoundException
      SlackAPI.logger.warn('Slack tokens table not created yet.')
      nil
    end

    # Puts a new token and API key into DynamoDB
    def self.put_slack_token(access_key:, slack_token:)
      mapping = SlackToken.new(access_key: access_key,
                               slack_token: slack_token)
      mapping.save
      true
    rescue Dynamoid::Errors::ConditionalCheckFailedException
      puts "WARN: This access key already has a Slack token. We will check for \
existing tokens and provide a refresh mechanism in a future commit."
      true
    rescue Exception => e
      SlackAPI.logger.error("We weren't able to save this token: #{e}")
      false
    end

    def self.has_token?(event:)
      access_key = get_access_key_from_event(event)
      results = SlackToken.where(access_key: access_key)
      return nil if results.nil? || results.count.zero?

      !results.first.slack_token.nil?
    rescue Exception => e
      SlackAPI.logger.warn("Error while querying for an existing token; beware stranger tings: #{e}")
      false
    end

    def self.reauthenticate?(event:)
      event.dig('queryStringParameters', 'reauthenticate') == 'true'
    end

    # Because the Slack OAuth service invokes /callback after the
    # user successfully authenticates, /callback will not be able to resolve
    # the original client's API key. We use that API key to store their token
    # and (later) their default workspace. This fixes that by creating a
    # table mapping access keys to `state_id`s.
    #
    # This introduces a security vulnerability where someone can change
    # another user's Slack token by invoking
    # /callback (a public method, as required by Slack OAuth) with a correct
    # state ID. We will need to fix that at some point.
    def self.associate_access_key_to_state_id!(event:, state_id:)
      begin
        access_key = get_access_key_from_event(event)
      rescue StandardError
        puts "WARN: Unable to get access key from context while trying to associate \
access key with state."
        return false
      end

      begin
        association = SlackAuthState.new(state_id: state_id,
                                         access_key: access_key)
        association.save
        true
      rescue Exception => e
        SlackAPI.logger.error("Unable to save auth state: #{e}")
        false
      end
    end

    # Gets an access key from a given state ID
    def self.get_access_key_from_state(state_id:)
      results = SlackAuthState.where(state_id: state_id)
      return nil if results.nil? || results.count.zero?

      results.first.access_key
    rescue Aws::DynamoDB::Errors::ResourceNotFoundException
      SlackAPI.logger.warn('State associations table not created yet.')
      nil
    end

    def self.configure_aws!
      return false if ENV['APP_AWS_SECRET_ACCESS_KEY'].nil? || ENV['APP_AWS_ACCESS_KEY_ID'].nil?

      begin
        ::Aws.config.update(
          credentials: ::Aws::Credentials.new(ENV['APP_AWS_ACCESS_KEY_ID'],
                                              ENV['APP_AWS_SECRET_ACCESS_KEY'])
        )
        true
      rescue Exception => e
        SlackAPI.logger.error("Unable to configure Aws: #{e}")
        false
      end
    end
  end
end
