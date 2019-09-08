require 'spec_helper'

describe 'Slack API Basics' do
  it 'Should ping back' do
    expected_response = {
      :statusCode => 200,
      :body => "sup dawg"
    }
    expect(Health.ping).to eq expected_response
  end
end
