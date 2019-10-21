require 'spec_helper'
require 'ostruct'

describe "Handling fucking Slack OAuth" do
  context "Slack OAuth callback" do
    it "Should show me the next place to go", :unit do
      fake_event = JSON.parse({
        queryStringParameters: {
          code: 'fake-code',
          state: 'fake-state'
        },
        requestContext: {
          path: '/develop/callback'
        },
        headers: {
          Host: 'example.fake'
        }
      }.to_json) # doing this so that we get string keys
      expected_response = {
        statusCode: 200,
        body: {
          go_here: "https://example.fake/develop/finish_auth?code=fake-code&state=fake-state"
        }.to_json
      }
      expect(SlackAPI::Auth.handle_callback(fake_event))
        .to eq(expected_response)
    end

    it "Should show me an error when a user denies the request", :unit do
      fake_event = JSON.parse({
        'queryStringParameters': {
          'error': 'access-denied'
        }
      }.to_json) # doing this so that we get string keys
      expected_response = {
        statusCode: 403,
        body: { message: 'User denied this app access to their Slack account.' }.to_json
      }
      expect(SlackAPI::Auth.handle_callback(fake_event))
        .to eq(expected_response)
    end
  end

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
      expected_message = "You will need to authenticate into Slack first. \
To do so, click on or copy/paste \
the link below, then go to /finish_auth with the code given once done: \
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
      expected_message = "You will need to authenticate into Slack first. \
To do so, click on or copy/paste \
the link below, then go to /finish_auth with the code given once done: \
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

  context 'Finishing authentication' do
    it "Should give me a token once I finish auth", :unit do
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
      slack_response_json = {
        access_token: 'fake-token',
        scope: 'read'
      }.to_json
      slack_response = instance_double(HTTParty::Response, body: slack_response_json)
      allow(SlackAPI::Slack::OAuth).to receive(:get).and_return slack_response
      expected_response = {
        statusCode: 200,
        body: { status: 'ok', token: 'fake-token' }.to_json
      }
      expect(SlackAPI::Auth::finish_auth(fake_event)).to eq expected_response
    end
  end

end
