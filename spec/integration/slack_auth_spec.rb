require 'spec_helper'

describe "Slack OAuth" do
  it "Should have an endpoint available for handling callbacks", :integration do
    uri = [
      @api_gateway_url,
      "handle_callback?code=fake-code&state=fake-state-id"
    ].join '/'
    response = Net::HTTP.get_response URI(uri)
    expect(response.code.to_i).to eq 200
    expect(response.body).to eq({
      code: 'fake-code'
    }.to_json)
  end
end
