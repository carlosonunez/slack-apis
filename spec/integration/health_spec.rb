# frozen_string_literal: true

require 'spec_helper'

describe 'Slack API Health', :integration do
  it 'pings back' do
    response = Net::HTTP.get_response URI("#{$api_gateway_url}/ping")
    expect(response.code.to_i).to eq 200
    expect(response.body).to eq({ message: 'sup dawg' }.to_json)
  end
end
