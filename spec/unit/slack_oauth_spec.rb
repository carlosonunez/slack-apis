require 'spec_helper'

describe "Slack OAuth methods" do
  context 'Getting tokens' do
    it "Should get a token", :unit do
      url_to_mock = 'https://slack.com/api/oauth.access'
      request_opts = {
        headers: { 'Content-Type': 'application/x-www-formencoded' },
        body: nil,
        query: {
          client_id: 'fake',
          client_secret: 'fake',
          code: 'fake',
          redirect_uri: 'fake'
        }
      }
      mocked_response_body = { access_token: 'fake-token' }.to_json
      allow(HTTParty).to receive(:post)
        .with(url_to_mock, request_opts)
        .and_return(double(HTTParty::Response, code: 200, body: mocked_response_body))
      response = SlackAPI::Slack::OAuth.access(client_id: 'fake',
                                               client_secret: 'fake',
                                               code: 'fake',
                                               redirect_uri: 'fake')
      access_token = JSON.parse(response.body)['access_token']
      expect(access_token).to eq 'fake-token'

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
end
