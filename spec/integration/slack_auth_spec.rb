require 'spec_helper'

describe "Slack OAuth" do
  before(:all) do
    @final_auth_url = String.new
  end

  context "Step 1" do
    it "Should give me a URL to continue authenticating", :integration do
      uri = "#{$api_gateway_url}/auth?workspace=#{ENV['SLACK_WORKSPACE_NAME']}"
      response = HTTParty.get(uri, {
        headers: { 'x-api-key': $test_api_key }
      })
      expected_message_re = %r{You will need to authenticate into Slack first. \
To do so, click on or copy/paste the link below, then go to /finish_auth with the code given once done: \
https://#{ENV['SLACK_WORKSPACE_NAME']}.slack.com\
/oauth/authorize\?client_id=#{ENV['SLACK_APP_CLIENT_ID']}&\
scope=users.profile:read,users.profile:write&\
redirect_uri=#{$api_gateway_url}/callback&state=[a-zA-Z0-9]{32}}
      expect(response.code.to_i).to eq 200
      expect(JSON.parse(response.body)['message']).to match expected_message_re
    end
  end

  # We need to use Capybara here since retrieving the final authentication URL
  # requires user action through a GUI.
  context "Step 2" do
    it "Should get a URL to finish authenticating", :integration do
      uri = "#{$api_gateway_url}/auth?workspace=#{ENV['SLACK_WORKSPACE_NAME']}"
      response = HTTParty.get(uri, {
        headers: { 'x-api-key': $test_api_key }
      })
      message = JSON.parse(response.body)['message']
      auth_url = message.match('^.*once done: (http.*)$').captures[0]

      visit(auth_url)
      fill_in "email", with: ENV['SLACK_SANDBOX_ACCOUNT_EMAIL']
      fill_in "password", with: ENV['SLACK_SANDBOX_ACCOUNT_PASSWORD']
      click_button "signin_btn"
      click_button "Allow"
      expect(page).to have_content 'go_here'

      next_url_serialized = page.html.match('.*({\"go_here\".*})')[1]
      next_url = JSON.parse(next_url_serialized)
      expect(next_url['go_here']).not_to be_nil

      @final_auth_url << next_url['go_here']
    end
  end

  context "Step 3" do
    it "Should provide me with a token", :integration do
      response = HTTParty.get(@final_auth_url, {
        headers: { 'x-api-key': $test_api_key }
      })
      expect(response.code.to_i).to eq 200
      expect(JSON.parse(response.body)['status']).to eq 'ok'
    end
  end
end
