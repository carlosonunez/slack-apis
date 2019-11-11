require 'aws-sdk-dynamodb'
require 'slack-api/aws_helpers/api_gateway'
require 'slack-api/slack'
require 'logger'
require 'securerandom'
require 'dynamoid'

module SlackAPI
  module Auth
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
    def self.finish_auth(event)
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
      SlackAPI::AWSHelpers::APIGateway.return_200(
        body: nil,
        json: { status: 'ok', token: token }
      )
    end

=begin
    Slack uses OAuth 2.0. Part of this workflow is providing the server (Slack)
    with a `redirect_uri` that the server can use to send a secret code that the
    client (this) sends back to retrieve a token.

    This method saves the code and the `state` parameter it's attached to
    into a DynamoDb table. Since these codes expire in ten minutes, there is
    little risk of someone logging in as someone else if someone somehow
    manages to obtain access to this database. The intent is that
    a call to the `continue_authorizing` endpoint pulls this code when given
    a `state` and completes the OAuth flow.

    In other words, this is a non-webserver way of authenticating via OAuth 2.0.

    In other _other_ words, this is probably terrible.
=end
    @@oauth_token_table_name = 'slack_api_tokens'
    @@logger = Logger.new(STDOUT)
    @@logger.level = ENV['LOG_LEVEL'] || Logger::WARN

    def self.save_oauth_token!(access_key:, token:)
      dynamodb_client = Aws::DynamoDB::Client.new
      self.create_oauth_token_table_if_not_present client: dynamodb_client
      self.insert_oauth_token_into_table(client: dynamodb_client,
                                         access_key: access_key,
                                         token: token)
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
    # TODO: IN PROGRESS
    def self.get_slack_token_from_key(context:)
      SlackAPI::AWSHelpers::APIGateway.return_404(body: 'No token exists for this access key.')
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

    def self.insert_oauth_token_into_table(client:, access_key:, token:)
      @@logger.debug("Inserting new OAuth token")
      client.put_item({
        table_name: @@oauth_token_table_name,
        item: {
          "access_key" => { s: access_key },
          "token" => { s: token }
        }
      })
    end

    # For more info on key_type and attribute_types,
    # check out this StackOverflow answer:
    # https://stackoverflow.com/questions/45581744/how-does-dynamodb-partition-key-works
    def self.create_oauth_token_table_if_not_present(client:)
      oauth_token_tables_found = client.list_tables.table_names.select { |name|
        name == @@oauth_token_table_name
      }
      if oauth_token_tables_found.empty?
        @@logger.info("Creating new temp code table.")
        oauth_token_table_kvp = {
          access_key: { key_type: 'HASH', attribute_type: 'S' },
          token: { key_type: 'SORT', attribute_type: 'S' }
        }
        table_properties = {key_schema: [], attribute_definitions: []}
        oauth_token_table_kvp.each do |table_key, key_properties|
          table_properties[:key_schema].push({
            attribute_name: table_key,
            key_type: key_properties[:key_type]
          })
          table_properties[:attribute_definitions].push({
            attribute_name: table_key,
            attribute_type: key_properties[:attribute_type]
          })
        end
        begin
          client.create_table(table_name: @@oauth_token_table_name,
                              key_schema: table_properties[:key_schema],
                              attribute_definitions: table_properties[:attribute_definitions],
                              billing_mode: "PAY_PER_REQUEST")
        rescue Exception => e
          raise "Failed to create temp table: #{e}"
        end
      end
    end
  end
end
