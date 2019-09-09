require 'spec_helper'

describe 'Slack API Basics' do
  it 'Should ping back' do
    expected_response = Helpers::Unit::Aws::ApiGateway.return_200 body: "sup dawg"
    expect(SlackAPI::Health.ping).to eq expected_response
  end
end
