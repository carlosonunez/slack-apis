require 'aws-sdk-dynamodb'
require 'slack-api/aws_helpers/api_gateway'
require 'logger'

module SlackAPI
  module Auth
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
    @@temp_code_table_name = 'slack_api_temp_oauth_codes'
    @@logger = Logger.new(STDOUT)
    @@logger.level = ENV['LOG_LEVEL'] || Logger::WARN

    def self.save_temp_code(state:, code:)
      dynamodb_client = Aws::DynamoDB::Client.new
      self.create_temp_code_table_if_not_present client: dynamodb_client
      self.insert_temp_code_into_table(client: dynamodb_client,
                                       temp_code: code,
                                       state_id: state)
    end

    def self.begin_authentication_flow
      @@logger.info "This still needs to be built!"
      message = <<-MESSAGE
You will need to authenticate into Slack first. To do so, click on or copy/paste
the link below, then go to /finish_authentication once done:
https://slack.com/oauth/authorize?client_id=fake&\
scope=users.profile:write,users.write,users.profile:read&\
redirect_uri=https://example.fake/callback&\
state=api-key
      MESSAGE
      SlackAPI::AWSHelpers::APIGateway.return_200(body: message)
    end

    private
    def self.insert_temp_code_into_table(client:, temp_code:, state_id:)
      @@logger.debug("Inserting new temp code; state: #{state_id}, code: #{temp_code}")
      client.put_item({
        table_name: @@temp_code_table_name,
        item: {
          "state" => { s: state_id },
          "code" => { s: temp_code }
        }
      })
    end

    # For more info on key_type and attribute_types,
    # check out this StackOverflow answer:
    # https://stackoverflow.com/questions/45581744/how-does-dynamodb-partition-key-works
    def self.create_temp_code_table_if_not_present(client:)
      temp_code_tables_found = client.list_tables.table_names.select { |name|
        name == @@temp_code_table_name
      }
      if temp_code_tables_found.empty?
        @@logger.info("Creating new temp code table.")
        temp_code_table_kvp = {
          state: { key_type: 'HASH', attribute_type: 'S' },
          code: { key_type: 'SORT', attribute_type: 'S' }
        }
        table_properties = {key_schema: [], attribute_definitions: []}
        temp_code_table_kvp.each do |table_key, key_properties|
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
          client.create_table(table_name: @@temp_code_table_name,
                              key_schema: table_properties[:key_schema],
                              attribute_definitions: table_properties[:attribute_definitions],
                              billing_mode: "PAY_PER_REQUEST")
        rescue Exception => e
          SlackAPI::AWSHelpers::APIGateway::return_500(
            error_message: "Failed to create temp table: #{e}"
          )
        end
      end
    end
  end
end
