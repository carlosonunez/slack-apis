require 'spec_helper'

describe "Slack Profiles" do
  # We require a specific user ID due to the limited scopes this external
  # bot will have and it likely needing to be used against Slack workspaces
  # that are subject to GDPR.
  it "Should set the user's profile", :unit do
    fake_event = JSON.parse({
      queryStringParameters: {
        user: 'fake-user',
        token: 'fake-token'
      },
      body: {
        status: 'fake-status',
        emoji: ':joy:'
      }
    }.to_json)
    slack_response_json = {
      ok: true,
      profile: {
        status_text: 'fake-status',
        status_emoji: ':joy:'
      }
    }.to_json
    slack_response = instance_double(HTTParty::Response, body: slack_response_json)
    allow(SlackAPI::Slack::OAuth).to receive(:get).and_return slack_response
    expected_response = {
      statusCode: 200,
      body: {
        status: 'ok',
        changed: {
          text: {
            old: 'old-status',
            new: 'new-status'
          },
          emoji: {
            old: ':ok:',
            new: ':joy:'
          }
        }
      }
    }.to_json
    expect(SlackAPI::Slack::Profile.set(fake_event)).to eq expected_response
  end
end
