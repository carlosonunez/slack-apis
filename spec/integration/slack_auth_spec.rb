require 'spec_helper'

describe "Slack OAuth" do
  it "Should have an endpoint available for handling callbacks", :integration do
    uri = [
      $api_gateway_url,
      "handle_callback?code=fake-code&state=fake-state-id"
    ].join '/'
    response = HTTParty.get uri
    expect(response.code.to_i).to eq 200
    expect(response.body).to eq({
      code: 'fake-code'
    }.to_json)
  end

  context "Slack OAuth - Step 1" do
    it "Should give me a URL to continue authenticating", :integration do
      uri = [
        $api_gateway_url,
        "begin_authentication"
      ].join '/'
      headers = {
        'x-api-key': ENV["API_KEY"]
      }
      response = HTTParty.get(uri, headers)
      expected_message = "You will need to authenticate into Slack first. \
To do so, click on or copy/paste \
the link below, then go to /finish_authentication once done: \
https://slack.com/oauth/authorize?client_id=#{ENV['SLACK_APP_CLIENT_ID']}&\
scope=users.profile:read,users.profile:write&\
redirect_uri=https://#{$api_gateway}/develop/handle_callback&\
state=fake-state-id"
      expect(response.code.to_i).to eq 200
      expect(response.body).to eq(expected_message)
    end
  end
end
