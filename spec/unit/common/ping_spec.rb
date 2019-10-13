require 'spec_helper'

describe 'Slack API Basics' do
  it 'Should ping back', :unit do
    expected_response = {
      body: { message: 'sup dawg' }.to_json,
      statusCode: 200
    }
    expect(SlackAPI::Health.ping).to eq expected_response
  end
end
