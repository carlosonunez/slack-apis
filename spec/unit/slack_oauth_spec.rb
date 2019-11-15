require 'spec_helper'
require 'ostruct'

describe "Handling fucking Slack OAuth" do
  context "Not authenticated yet" do
    it "Should give the user an auth init prompt without providing a workspace", :unit do
      expect(SecureRandom).to receive(:hex).and_return('fake-state-id')
      fake_event = JSON.parse({
        queryStringParameters: {
          workspace: 'fake'
        },
        requestContext: {
          path: '/develop/auth'
        },
        headers: {
          Host: 'example.fake'
        }
      }.to_json)
      expected_message = "You will need to authenticate into Slack first; \
click on or copy/paste this URL to get started: \
https://fake.slack.com/oauth/authorize?client_id=fake&\
scope=users.profile:read,users.profile:write&\
redirect_uri=https://example.fake/develop/callback&\
state=fake-state-id"
      expected_response = {
        statusCode: 200,
        body: { message: expected_message }.to_json
      }
      expect(SlackAPI::Auth::begin_authentication_flow(fake_event,
                                                      client_id: 'fake'))
        .to eq expected_response
    end

    it "Should give the user an auth init prompt when a workspace is provided", :unit do
      expect(SecureRandom).to receive(:hex).and_return('fake-state-id')
      fake_event = JSON.parse({
        requestContext: {
          path: '/develop/auth'
        },
        headers: {
          Host: 'example.fake'
        }
      }.to_json)
      expected_message = "You will need to authenticate into Slack first; \
click on or copy/paste this URL to get started: \
https://slack.com/oauth/authorize?client_id=fake&\
scope=users.profile:read,users.profile:write&\
redirect_uri=https://example.fake/develop/callback&\
state=fake-state-id"
      expected_response = {
        statusCode: 200,
        body: { message: expected_message }.to_json
      }
      expect(SlackAPI::Auth::begin_authentication_flow(fake_event,
                                                      client_id: 'fake'))
        .to eq expected_response
    end
  end

  context "Slack OAuth callback" do
    it "Should ok if I was able to get a token", :unit do
      expected_response = {
        statusCode: 200,
        body: { status: 'ok' }.to_json
      }
      fake_context = JSON.parse({
        identity: {
          apiKey: 'fake-key'
        }
      }.to_json)
      fake_event = JSON.parse({
        requestContext: {
          path: '/develop/final_auth'
        },
        queryStringParameters: {
          code: 'fake-code',
          state: 'fake-state'
        },
        headers: {
          Host: 'example.host'
        }
      }.to_json)
      allow(SlackAPI::Slack::OAuth).to receive(:access).and_return(OpenStruct.new(
        body: {
          ok: true,
          access_token: 'fake-token',
          scope: 'read'
        }.to_json))
      expect(SlackAPI::Auth::handle_callback(fake_event, fake_context)).to eq expected_response
    end
  end


  context 'Tokens' do
    it "Should give me an error message when retrieving tokens while not authenticated", :unit do
      Helpers::Aws::DynamoDBLocal.drop_tables!
      fake_context = JSON.parse({
        identity: {
          apiKey: 'fake-key'
        }
      }.to_json)
      expected_response = {
        statusCode: 404,
        body: { message: 'No token exists for this access key.' }.to_json
      }
      expect(SlackAPI::Auth::get_slack_token(context: fake_context)).to eq expected_response
    end

    it "Should persist tokens with their associated API keys", :unit do
      fake_context = JSON.parse({
        identity: {
          apiKey: 'fake-key'
        }
      }.to_json)
      expected_response = {
        statusCode: 200,
        body: { status: 'ok' }.to_json
      }
      expected_get_response = {
        statusCode: 200,
        body: { token: 'fake' }.to_json
      }
      expect(SlackAPI::Auth::put_slack_token(context: fake_context,
                                             slack_token: 'fake')).to eq expected_response
      expect(SlackAPI::Auth::get_slack_token(context: fake_context)).to eq expected_get_response
    end
  end
end
