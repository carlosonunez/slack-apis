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

    it 'Should error if token is expired', :unit do
    fake_event = JSON.parse({
      requestContext: {
        identity: {
          apiKey: 'fake-key'
        }
      },
      queryStringParameters: {
        workspace: 'fake-workspace',
        user: 'fake-user',
        status: 'fake-status'
      }
    }.to_json)
    expected_response = {
      statusCode: 403,
      body: {
        status: 'error',
        message: 'Token expired'
      }.to_json,
    }
    allow(SlackAPI::Auth).to receive(:get_slack_token).and_return 'fake-token'
    allow(SlackAPI::Slack::OAuth).to receive(:token_expired?).and_return true
    expect(SlackAPI::Slack::Profile::Status.set!(fake_event)).to eq expected_response
    end
  end

  context 'Profile setting' do
    fake_event = JSON.parse({
      requestContext: {
        identity: {
          apiKey: 'fake-key'
        }
      },
      queryStringParameters: {
        workspace: 'fake-workspace',
        user: 'fake-user',
        status: 'fake-status'
      }
    }.to_json)
    fake_responses = {
      get: {
        url: "https://fake-workspace.slack.com/users.profile.get",
        options: {
          headers: {
            'Content-Type': 'application/x-www-formencoded'
          },
          query: {
            token: 'fake-token',
            user: 'fake-user'
          }
        },
        response: {
          ok: true,
          profile: {
            status_text: 'old-status',
            status_emoji: ':ok:'
          }
        }.to_json
      },
      post: {
        url: "https://fake-workspace.slack.com/users.profile.set",
        options: {
          headers: {
            'Content-Type': 'application/json'
          },
          query: {
            token: 'fake-token',
            user: 'fake-user',
            profile: {
              status_text: 'new-status',
              status_emoji: ':ok:'
            }.to_json
          }
        },
        response_body: {
          ok: true,
          profile: {
            status_text: 'new-status',
            status_emoji: ':ok:'
          }
        }.to_json
      }
    }
    it "Should set the user's profile", :unit do
      expected_response = {
        statusCode: 200,
        body: {
          status: 'ok',
          changed: {
            old: ':ok: old-status',
            new: ':ok: new-status'
          }
        }
      }.to_json
      allow(SlackAPI::Auth).to receive(:get_slack_token).and_return 'fake-token'
      allow(SlackAPI::Slack::OAuth).to receive(:token_expired?).and_return false
      allow(SlackAPI::Slack::Users).to receive(:get_id).and_return 'fake-user'
      [:get, :post].each do |method|
        url = fake_responses[method][url]
        httparty_options = fake_responses[method][:options]
        mocked_response_body = fake_responses[method][:response_body]
        allow(HTTParty).to receive(method).with(url, httparty_options)
          .and_return(instance_double(HTTParty::Response, body: mocked_response_body))
      end
      expect(SlackAPI::Slack::Profile::Status.set!(fake_event)).to eq expected_response
    end
  end
end
