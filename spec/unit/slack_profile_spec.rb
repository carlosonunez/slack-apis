require 'spec_helper'

describe "Slack Profiles" do
  context 'Validation' do
    %w(user workspace).each do |required_thing|
      it "Should error if #{required_thing} is not set", :unit do
        fake_event = JSON.parse({
          requestContext: {
            identity: {
              apiKey: 'fake-key'
            }
          },
          queryStringParameters: {
            workspace: 'fake-workspace',
            user: 'fake-user',
            token: 'fake-token'
          },
          body: {
            status: 'fake-status',
            emoji: ':joy:'
          }
        }.to_json)
        fake_event['queryStringParameters'] =
          fake_event['queryStringParameters'].reject { |key,_| key == required_thing }
        expected_response = {
          statusCode: 422,
          body: {
            status: 'error',
            message: "Parameter required: #{required_thing}"
          }.to_json,
        }
        expect(SlackAPI::Slack::Profile::Status.set!(fake_event))
          .to eq expected_response
      end
    end
  end

  it "Should set the user's profile", :wip do
    fake_event = JSON.parse({
      requestContext: {
        identity: {
          apiKey: 'fake-key'
        }
      },
      queryStringParameters: {
        workspace: 'fake-workspace',
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
