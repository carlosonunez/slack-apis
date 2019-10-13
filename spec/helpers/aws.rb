module Helpers
  module Aws
    def self.get_stubbed_client(aws_service:,mocked_responses:)
        # TODO: It might make sense to have a YAML way of doing this.
        responses = mocked_responses
        stubbed_client = Object.const_get("Aws::#{aws_service}::Client").send(
          'new',
          stub_responses: true
        )
        responses.each do |api_call, stubbed_response|
          stubbed_client.stub_responses(api_call, stubbed_response)
        end
        stubbed_client
    end
  end
end
