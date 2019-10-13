require 'aws-sdk-dynamodb'

module Helpers
  module Aws
    module DynamoDB
      def self.get_stubbed_client(mocked_responses:)
        # TODO: If we start having multiple DynamoDB scenarios, fetch this info from a YAML.
        responses = mocked_responses
        stubbed_client = ::Aws::DynamoDB::Client.new(stub_responses: true)
        responses.each do |api_call, stubbed_response|
          stubbed_client.stub_responses(api_call, stubbed_response)
        end
        stubbed_client
      end
    end
  end
end
