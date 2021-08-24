# frozen_string_literal: true

require 'spec_helper'

describe 'Slack user methods' do
  context 'Who am I?' do
    it 'gives me a user ID associated with my token', :unit do
      url_to_mock = 'https://slack.com/api/users.identity'
      request_opts = {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer fake-token'
        }.transform_keys(&:to_s),
        params: nil,
        debug_output: nil
      }
      mocked_response_body = {
        status: 'ok',
        user: {
          id: 'fake-id'
        },
        team: {
          id: 'fake-team-id'
        }
      }.to_json
      allow(HTTParty).to receive(:get)
        .with(url_to_mock, request_opts)
        .and_return(double(HTTParty::Response, code: 200, body: mocked_response_body))
      response = SlackAPI::Slack::Users.get_id(token: 'fake-token')
      expect(response).to eq 'fake-id'
    end
  end
end
