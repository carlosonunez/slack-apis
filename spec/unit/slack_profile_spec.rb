require 'spec_helper'

describe "Slack Profiles" do
  context 'Validation' do
    it "Should error if status is not set", :unit do
      fake_event = JSON.parse({
        requestContext: {
          identity: {
            apiKey: 'fake-key'
          }
        },
        queryStringParameters: {
          token: 'fake-token'
        },
        body: {
          status: 'fake-status',
          emoji: ':joy:'
        }
      }.to_json)
      expected_response = {
        statusCode: 422,
        body: {
          status: 'error',
          message: "Parameter required: text"
        }.to_json,
      }
      expect(SlackAPI::Slack::Profile::Status.set!(fake_event))
        .to eq expected_response
    end

    it 'Should error if token is expired', :unit do
    fake_event = JSON.parse({
      requestContext: {
        identity: {
          apiKey: 'fake-key'
        }
      },
      queryStringParameters: {
        text: 'fake-status'
      }
    }.to_json)
    expected_response = {
      statusCode: 403,
      body: {
        status: 'error',
        message: 'Token expired'
      }.to_json,
    }
    allow(SlackAPI::Auth).to receive(:get_slack_token).and_return({
      statusCode: 200,
      body: { token: 'fake-token' }.to_json
    })
    allow(SlackAPI::Slack::OAuth).to receive(:token_expired?).and_return true
    expect(SlackAPI::Slack::Profile::Status.set!(fake_event)).to eq expected_response
    end
  end

  context 'Profile setting' do
    fake_responses = {
      get: {
        url: "https://slack.com/api/users.profile.get",
        options: {
          headers: {
            'Content-Type': 'application/x-www-formencoded'
          },
          query: {
            token: 'fake-token'
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
        url: "https://slack.com/api/users.profile.set",
        options: {
          headers: {
            'Content-Type': 'application/json'
          },
          body: nil,
          query: {
            token: 'fake-token',
            profile: {
              status_text: 'new-status',
              status_emoji: ':ok:'
            }.to_json
          }
        },
        response: {
          ok: true,
          profile: {
            status_text: 'new-status',
            status_emoji: ':ok:'
          }
        }.to_json
      }
    }
    it "Should set the user's profile", :unit do
      fake_event = JSON.parse({
        requestContext: {
          identity: {
            apiKey: 'fake-key'
          }
        },
        queryStringParameters: {
          text: 'new-status'
        }
      }.to_json)
      expected_response = {
        body: {
          status: 'ok',
          changed: {
            old: ':ok: old-status',
            new: ':ok: new-status'
          }
        }.to_json,
        statusCode: 200
      }
      allow(SlackAPI::Auth).to receive(:get_slack_token).and_return({
        statusCode: 200,
        body: { token: 'fake-token' }.to_json
      })
      allow(SlackAPI::Slack::OAuth).to receive(:token_expired?).and_return false
      [:get, :post].each do |method|
        url = fake_responses[method][:url]
        httparty_options = fake_responses[method][:options]
        mocked_response_body = fake_responses[method][:response]
        allow(HTTParty).to receive(method).with(url, httparty_options)
          .and_return(double(HTTParty::Response, code: 200, body: mocked_response_body))
      end
      expect(SlackAPI::Slack::Profile::Status.set!(fake_event)).to eq expected_response
    end

    it "Should set the user's profile and support emojis 💪 🚀", :unit do
      fake_event = JSON.parse({
        requestContext: {
          identity: {
            apiKey: 'fake-key'
          }
        },
        queryStringParameters: {
          text: 'new-status',
          emoji: ':rocket:'
        }
      }.to_json)
      expected_response = {
        body: {
          status: 'ok',
          changed: {
            old: ':ok: old-status',
            new: ':rocket: new-status'
          }
        }.to_json,
        statusCode: 200
      }
      new_emoji = ':rocket:'
      fake_responses[:post][:options][:query][:profile].gsub!(/:ok:/,new_emoji)
      fake_responses[:post][:response].gsub!(/:ok:/,new_emoji)
      allow(SlackAPI::Auth).to receive(:get_slack_token).and_return({
        statusCode: 200,
        body: { token: 'fake-token' }.to_json
      })
      allow(SlackAPI::Slack::OAuth).to receive(:token_expired?).and_return false
      [:get, :post].each do |method|
        url = fake_responses[method][:url]
        httparty_options = fake_responses[method][:options]
        mocked_response_body = fake_responses[method][:response]
        allow(HTTParty).to receive(method).with(url, httparty_options)
          .and_return(double(HTTParty::Response, code: 200, body: mocked_response_body))
      end
      expect(SlackAPI::Slack::Profile::Status.set!(fake_event)).to eq expected_response
    end

    it "Shouldn't change my status if nothing changed", :unit do
      fake_event = JSON.parse({
        requestContext: {
          identity: {
            apiKey: 'fake-key'
          }
        },
        queryStringParameters: {
          text: 'new-status',
          emoji: ':rocket:'
        }
      }.to_json)
      expected_response = {
        body: {
          status: 'ok',
          changed: {}
        }.to_json,
        statusCode: 200
      }
      new_emoji = ':rocket:'
      fake_responses[:get][:response]
        .gsub!(/:ok:/,new_emoji)
        .gsub!(/old-status/, 'new-status')
      fake_responses[:post][:options][:query][:profile]
        .gsub!(/:ok:/,new_emoji)
      allow(SlackAPI::Auth).to receive(:get_slack_token).and_return({
        statusCode: 200,
        body: { token: 'fake-token' }.to_json
      })
      allow(SlackAPI::Slack::OAuth).to receive(:token_expired?).and_return false
      [:get, :post].each do |method|
        url = fake_responses[method][:url]
        httparty_options = fake_responses[method][:options]
        mocked_response_body = fake_responses[method][:response]
        allow(HTTParty).to receive(method).with(url, httparty_options)
          .and_return(double(HTTParty::Response, code: 200, body: mocked_response_body))
      end
      expect(SlackAPI::Slack::Profile::Status.set!(fake_event)).to eq expected_response
    end
  end
end
