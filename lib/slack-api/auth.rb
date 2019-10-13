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

    def self.create_temp_code_table_if_not_present(client:)
      temp_code_tables_found = client.list_tables.table_names.select { |name|
        name == @@temp_code_table_name
      }
      if temp_code_tables_found.empty?
        puts "INFO: Creating temp table."
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
