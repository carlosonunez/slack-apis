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
        config.namespace = "slack_auth"
        config.logger.level = Logger::FATAL
      end

      include Dynamoid::Document
      table name: :tokens, key: :access_key, read_capacity: 2, write_capacity: 2
      field :access_key
      field :slack_token
    end

    class SlackAuthState
      Dynamoid.configure do |config|
        config.namespace = "slack_auth_state"
        config.logger.level = Logger::FATAL
      end

      include Dynamoid::Document
      table name: :state_associations, key: :state_id, read_capacity: 2, write_capacity: 2
      field :access_key
      field :state_id
    end
=begin
    Handle Slack OAuth callbacks.
=end
    def self.handle_callback(event, context)
      parameters = event['queryStringParameters']
      raise "Parameters missing a code or error" \
        if (parameters['code'].nil? and parameters['state'].nil?) \
          and parameters['error'].nil?
      if (!parameters['code'].nil? and !parameters['state'].nil?)
        callback_url = SlackAPI::AWSHelpers::APIGateway.get_endpoint(event) + '/callback'
        token_response = SlackAPI::Slack::OAuth.access(client_id: ENV['SLACK_APP_CLIENT_ID'],
                                                       client_secret: ENV['SLACK_APP_CLIENT_SECRET'],
                                                       redirect_uri: callback_url,
                                                       code: parameters['code'])
        raise "Unable to get Slack token" if token_response.body.nil?
        token_response_json = JSON.parse(token_response.body)
        if !token_response_json['ok'].nil? and !token_response_json['ok']
          return SlackAPI::AWSHelpers::APIGateway.return_403(
            body: "Token request failed: #{token_response_json['error']}"
          )
        end
        token = token_response_json['access_token']
        self.put_slack_token(context: context, slack_token: token)
      elsif !parameters['error'].nil?
        SlackAPI::AWSHelpers::APIGateway.return_403(
          body: 'User denied this app access to their Slack account.'
        )
      end
    end

=begin
    Provide a first step for the authentication flow.
=end
    def self.begin_authentication_flow(event, context, client_id:)
      scopes_csv = ENV['SLACK_APP_CLIENT_SCOPES'] || "users.profile:read,users.profile:write"
      redirect_uri = "https://#{SlackAPI::AWSHelpers::APIGateway.get_endpoint(event)}/callback"
      workspace = self.get_workspace(event)
      state_id = self.generate_state_id
      if workspace.nil?
        workspace_url = "slack.com"
      else
        workspace_url = "#{workspace}.slack.com"
      end
      slack_authorization_uri = [
        "https://#{workspace_url}/oauth/authorize?client_id=#{client_id}",
        "scope=#{scopes_csv}",
        "redirect_uri=#{redirect_uri}",
        "state=#{state_id}"
      ].join '&'
      message = "You will need to authenticate into Slack first; click on or \
copy/paste this URL to get started: #{slack_authorization_uri}"
      begin
        self.associate_access_key_to_state_id!(context: context,
                                               state_id: state_id)
        SlackAPI::AWSHelpers::APIGateway.return_200(body: message)
      rescue
        SlackAPI::AWSHelpers::APIGateway.return_422(body: "Couldn't map state to access key.")
      end
    end

    # Retrives a Slack OAuth token from a API Gateway key
    def self.get_slack_token(context:)
      access_key = self.get_access_key_from_context(context)
      if access_key.nil?
        return SlackAPI::AWSHelpers::APIGateway.return_422(body: 'Access key missing.')
      end
      slack_token = self.get_slack_token_from_access_key(access_key)
      if slack_token.nil?
        return SlackAPI::AWSHelpers::APIGateway.return_404(body: 'No token exists for this access key.')
      end
      SlackAPI::AWSHelpers::APIGateway.return_200(
        body: nil,
        json: { token: slack_token }
      )
    end

    private
    def self.get_workspace(event)
      begin
        event['queryStringParameters']['workspace']
      rescue
        return nil
      end
    end

    def self.generate_state_id
      SecureRandom.hex
    end

    def self.get_access_key_from_context(context)
      context['identity']['apiKey']
    end

    def self.get_slack_token_from_access_key(access_key)
      begin
        results = SlackToken.where(access_key: access_key)
        return nil if results.count == 0
        results.first.slack_token
      rescue Aws::DynamoDB::Errors::ResourceNotFoundException
        puts "WARN: Slack tokens table not created yet."
        return nil
      end
    end

    # Puts a new token and API key into DynamoDB
    def self.put_slack_token(context:, slack_token:)
      access_key = self.get_access_key_from_context(context)
      if access_key.nil?
        return SlackAPI::AWSHelpers::APIGateway.return_422(body: 'Access key missing.')
      end
      begin
        mapping = SlackToken.new(access_key: access_key,
                                 slack_token: slack_token)
        mapping.save
        SlackAPI::AWSHelpers::APIGateway.return_200(
          body: nil,
          json: { status: 'ok' }
        )
      rescue Exception => e
        SlackAPI::AWSHelpers::APIGateway.return_422(
          body: "Saving token failed: #{e}"
        )
      end
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
    def self.associate_access_key_to_state_id!(context:, state_id:)
      begin
        access_key = self.get_access_key_from_context(context)
      rescue
        puts "WARN: Unable to get access key from context while trying to associate \
access key with state."
        return false
      end

      association = SlackAuthState.new(state_id: state_id,
                                       access_key: access_key)
      association.save
      return true
    end

    # Gets an access key from a given state ID
    def self.get_access_key_from_state(state_id:)
      begin
        results = SlackAuthState.where(state_id: state_id)
        return nil if results.nil? or results.count == 0
        results.first.access_key
      rescue Aws::DynamoDB::Errors::ResourceNotFoundException
        puts "WARN: State associations table not created yet."
        return nil
      end
    end
  end
end
