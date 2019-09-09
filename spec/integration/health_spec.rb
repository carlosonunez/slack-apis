require 'spec_helper'

describe 'Slack API Health' do
  it 'Should ping back' do
    response = Helpers::Integration::get endpoint: '/v1/ping'
    expect(response.status_code).to eq 200
    expect(response.body).to eq 'sup dawg'
  end
end
