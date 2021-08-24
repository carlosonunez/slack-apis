# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'

describe 'Slack OAuth' do
  context 'Handling state associations' do
    it 'saves access keys with state IDs', :unit do
      Helpers::Aws::DynamoDBLocal.drop_tables!
      fake_event = JSON.parse({
        requestContext: {
          identity: {
            apiKey: 'fake-key'
          }
        }
      }.to_json)
      SlackAPI::Auth.associate_access_key_to_state_id!(event: fake_event,
                                                       state_id: 'fake-state-id')
      expect(SlackAPI::Auth.get_access_key_from_state(state_id: 'fake-state-id'))
        .to eq 'fake-key'
    end
  end

  context 'Handling tokens' do
    it 'gives me an error message Retrieving tokens while not authenticated', :unit do
      Helpers::Aws::DynamoDBLocal.drop_tables!
      fake_event = JSON.parse({
        requestContext: {
          identity: {
            apiKey: 'fake-key'
          }
        }
      }.to_json)
      expected_response = {
        statusCode: 404,
        body: { status: 'error', message: 'No token exists for this access key.' }.to_json
      }
      expect(SlackAPI::Auth.get_slack_token(event: fake_event)).to eq expected_response
    end

    it 'persists tokens with their associated API keys', :unit do
      fake_event = JSON.parse({
        requestContext: {
          identity: {
            apiKey: 'fake-key'
          }
        }
      }.to_json)
      expected_get_response = {
        statusCode: 200,
        body: { status: 'ok', token: 'fake' }.to_json
      }
      expect(SlackAPI::Auth.put_slack_token(access_key: 'fake-key',
                                            slack_token: 'fake')).to be true
      expect(SlackAPI::Auth.get_slack_token(event: fake_event)).to eq expected_get_response
    end
  end

  context "We aren't authenticated yet" do
    it 'gives the user an auth init prompt without providing a workspace', :unit do
      Helpers::Aws::DynamoDBLocal.drop_tables!
      expect(SecureRandom).to receive(:hex).and_return('fake-state-id')
      fake_event = JSON.parse({
        queryStringParameters: {
          workspace: 'fake'
        },
        requestContext: {
          path: '/develop/auth',
          identity: {
            apiKey: 'fake-key'
          }
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
        body: { status: 'ok', message: expected_message }.to_json
      }
      expect(SlackAPI::Auth.begin_authentication_flow(fake_event,
                                                      client_id: 'fake'))
        .to eq expected_response
      expect(SlackAPI::Auth.get_access_key_from_state(state_id: 'fake-state-id'))
        .to eq 'fake-key'
    end

    it 'gives the user an auth init prompt when a workspace is provided', :unit do
      Helpers::Aws::DynamoDBLocal.drop_tables!
      expect(SecureRandom).to receive(:hex).and_return('fake-state-id')
      fake_event = JSON.parse({
        requestContext: {
          path: '/develop/auth',
          identity: {
            apiKey: 'fake-key'
          }
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
        body: { status: 'ok', message: expected_message }.to_json
      }
      expect(SlackAPI::Auth.begin_authentication_flow(fake_event,
                                                      client_id: 'fake'))
        .to eq expected_response
      expect(SlackAPI::Auth.get_access_key_from_state(state_id: 'fake-state-id'))
        .to eq 'fake-key'
    end

    it 'short-circuits this process if the user already has a token', :unit do
      Helpers::Aws::DynamoDBLocal.drop_tables!
      SlackAPI::Auth.put_slack_token(access_key: 'fake-key', slack_token: 'fake')
      fake_event = JSON.parse({
        requestContext: {
          path: '/develop/auth',
          identity: {
            apiKey: 'fake-key'
          }
        },
        headers: {
          Host: 'example.fake'
        }
      }.to_json)
      expected_response = {
        statusCode: 200,
        body: { status: 'ok', message: 'You already have a token.' }.to_json
      }
      expect(SlackAPI::Auth.begin_authentication_flow(fake_event,
                                                      client_id: 'fake'))
        .to eq expected_response
    end

    it 'avoids short-circuiting if we tell it to', :unit do
      Helpers::Aws::DynamoDBLocal.drop_tables!
      expect(SecureRandom).to receive(:hex).and_return('fake-state-id')
      SlackAPI::Auth.put_slack_token(access_key: 'fake-key-again', slack_token: 'fake')
      fake_event = JSON.parse({
        requestContext: {
          path: '/develop/auth',
          identity: {
            apiKey: 'fake-key-again'
          }
        },
        queryStringParameters: {
          reauthenticate: 'true'
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
        body: { status: 'ok', message: expected_message }.to_json
      }
      expect(SlackAPI::Auth.begin_authentication_flow(fake_event,
                                                      client_id: 'fake'))
        .to eq expected_response
      expect(SlackAPI::Auth.get_access_key_from_state(state_id: 'fake-state-id'))
        .to eq 'fake-key-again'
    end
  end

  context "We've been authenticated" do
    it 'oks if I was able to get a token', :unit do
      expected_response = {
        statusCode: 200,
        body: { status: 'ok' }.to_json
      }
      fake_event = JSON.parse({
        requestContext: {
          path: '/develop/callback',
          identity: {
            apiKey: 'fake-key'
          }
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
                                                                     }.to_json
                                                                   ))
      allow(SlackAPI::Auth).to receive(:get_access_key_from_state).and_return('fake-key')
      expect(SlackAPI::Auth.handle_callback(fake_event)).to eq expected_response
    end
  end
end
