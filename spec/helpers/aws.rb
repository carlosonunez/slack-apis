require 'aws-sdk'
require 'aws-sdk-dynamodb'

module Helpers
  module Aws
    module DynamoDBLocal
      def self.start_mocking!
        raise "Set the endpoint for DynamoDB local in your Docker Compose manifest \
with the AWS_DYNAMODB_ENDPOINT_URL environment variable" \
          if ENV['AWS_DYNAMODB_ENDPOINT_URL'].nil?
        ::Aws.config.update({
          endpoint: ENV['AWS_DYNAMODB_ENDPOINT_URL']
        })
      end

      def self.started?
        raise "DynamoDB is not configured for mocking; run 'start_mocking!' to do so" \
          if !self.is_dynamodb_mocked?
        dynamodb = ::Aws::DynamoDB::Client.new
        dynamodb.list_tables
        return true
      end

      private
      def self.is_dynamodb_mocked?
        ::Aws.config[:endpoint] == ENV['AWS_DYNAMODB_ENDPOINT_URL']
      end
    end
  end
end
