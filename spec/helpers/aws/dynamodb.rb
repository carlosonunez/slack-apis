require 'aws-sdk-dynamodb'

module Helpers
  module Aws
    module DynamoDB
      def self.get_stubbed_client
        # TODO: If we start having multiple DynamoDB scenarios, fetch this info from a YAML.
        responses = {
          put_item: ((OpenStruct.new).attributes = ['code', 'state', 'redirect_uri']),
          list_tables: [ "fake_table" ],
          create_table: ((OpenStruct.new).table_status = "CREATING")
        }
        stubbed_client = ::Aws::DynamoDB::Client.new(stub_responses: true)
        responses.each do |api_call, stubbed_response|
          stubbed_client.stub_responses(api_call, stubbed_response)
        end
      end
    end
  end
end
