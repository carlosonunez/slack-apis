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
=begin
    Handle Slack OAuth callbacks.
=end
    def self.handle_callback(event)
      parameters = event['queryStringParameters']
      raise "Parameters missing a code or error" \
        if (parameters['code'].nil? and parameters['state'].nil?) \
          and parameters['error'].nil?
      if (!parameters['code'].nil? and !parameters['state'].nil?)
        next_url = "https://" + \
          SlackAPI::AWSHelpers::APIGateway.get_endpoint(event, path_to_remove: '/callback') + \
          "/finish_auth?code=#{parameters['code']}&state=#{parameters['state']}"
        SlackAPI::AWSHelpers::APIGateway.return_200(
          body: nil,
          json: { go_here: next_url }
        )
      elsif !parameters['error'].nil?
        SlackAPI::AWSHelpers::APIGateway.return_403(
          body: 'User denied this app access to their Slack account.'
        )
      end
    end

=begin
    Finish the authentication flow when given a code and state. 
=end
    def self.finish_auth(event:, context:)
      raise "Code not in request" if event['queryStringParameters']['code'].nil?
      code = event['queryStringParameters']['code']
      callback_url = [
        "https://#{SlackAPI::AWSHelpers::APIGateway.get_endpoint(event, path_to_remove:'/finish_auth')}",
        "callback"
      ].join('/')

      token_response = SlackAPI::Slack::OAuth.access(client_id: ENV['SLACK_APP_CLIENT_ID'],
                                                    client_secret: ENV['SLACK_APP_CLIENT_SECRET'],
                                                    redirect_uri: callback_url,
                                                    code: code)
      raise "Unable to get Slack token" if token_response.body.nil?
      token_response_json = JSON.parse(token_response.body)
      if !token_response_json['ok'].nil? and !token_response_json['ok']
        return SlackAPI::AWSHelpers::APIGateway.return_403(
          body: "Token request failed: #{token_response_json['error']}"
        )
      end
      token = token_response_json['access_token']
      self.put_slack_token(context: context,
                           slack_token: token)
    end

    def self.begin_authentication_flow(event, client_id:)
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
      message = "You will need to authenticate into Slack first. To do so, \
click on or copy/paste the link below, then go to /finish_auth with the code given \
once done: #{slack_authorization_uri}"
      SlackAPI::AWSHelpers::APIGateway.return_200(body: message)
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
        json: { status: 'ok' }
      )
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
  end
end
