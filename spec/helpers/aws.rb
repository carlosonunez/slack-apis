# frozen_string_literal: true

require 'aws-sdk-dynamodb'
require 'dynamoid'

module Helpers
  module Aws
    module DynamoDBLocal
      def self.start_mocking!
        if ENV['AWS_DYNAMODB_ENDPOINT_URL'].nil?
          raise "Set the endpoint for DynamoDB local in your Docker Compose manifest \
with the AWS_DYNAMODB_ENDPOINT_URL environment variable"
        end
        ::Aws.config.update({
                              endpoint: ENV['AWS_DYNAMODB_ENDPOINT_URL']
                            })
      end

      def self.started?
        raise "DynamoDB is not configured for mocking; run 'start_mocking!' to do so" \
          unless is_dynamodb_mocked?

        dynamodb = ::Aws::DynamoDB::Client.new
        dynamodb.list_tables
        true
      end

      def self.drop_tables!
        Dynamoid.adapter.list_tables.each do |table|
          Dynamoid.adapter.delete_table(table) if table =~ /^#{Dynamoid::Config.namespace}/
        end
        Dynamoid.adapter.tables.clear
        Dynamoid.included_models.each { |m| m.create_table(sync: true) }
      end

      def self.is_dynamodb_mocked?
        ::Aws.config[:endpoint] == ENV['AWS_DYNAMODB_ENDPOINT_URL']
      end
    end
  end
end
