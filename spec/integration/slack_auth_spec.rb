require 'spec_helper'

describe "Slack OAuth" do
  it "Should have an endpoint available for handling callbacks", :integration do
    uri = [
      $api_gateway_url,
      "callback?code=fake-code&state=fake-state-id"
    ].join '/'
    response = HTTParty.get uri
    expect(response.code.to_i).to eq 200
    expect(response.body).to eq({
      code: 'fake-code'
    }.to_json)
  end

  context "Slack OAuth - Step 1" do
    it "Should give me a URL to continue authenticating", :integration do
      uri = "#{$api_gateway_url}/auth?workspace=#{ENV['SLACK_WORKSPACE_NAME']}"
      headers = {
        'x-api-key': $test_api_key
      }
      response = HTTParty.get(uri, headers)
      expected_message_re = %r{You will need to authenticate into Slack first. \
To do so, click on or copy/paste the link below, then go to \
/finish_authentication once done: \
https://#{ENV['SLACK_WORKSPACE_NAME']}.slack.com\
/oauth/authorize\?client_id=#{ENV['SLACK_APP_CLIENT_ID']}&\
scope=users.profile:read,users.profile:write&\
redirect_uri=https://x9gi2w2lal.execute-api.us-east-2.amazonaws.com/\
develop/callback&state=[a-zA-Z0-9]{32}}
      expect(response.code.to_i).to eq 200
      expect(JSON.parse(response.body)['message']).to match expected_message_re
    end
  end
end
