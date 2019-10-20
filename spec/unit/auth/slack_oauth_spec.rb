require 'spec_helper'
require 'ostruct'

describe "Handling fucking Slack OAuth" do
  context "Slack OAuth callback" do
    it "Should show me the code", :unit do
      fake_event = JSON.parse({
        'queryStringParameters': {
          'code': 'fake-code'
        }
      }.to_json) # doing this so that we get string keys
      expected_response = {
        statusCode: 200,
        body: { code: "fake-code" }.to_json
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
the link below, then go to /finish_authentication once done: \
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
the link below, then go to /finish_authentication once done: \
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
  context "During authentication" do
    it "Should save the OAuth code and state to DynamoDB", :unit do
      responses = {
        put_item: { consumed_capacity: { table_name: 'slack_api_temp_oauth_codes' } },
        list_tables: { table_names: [ "slack_api_temp_oauth_codes" ] },
        create_table: { table_description: { item_count: 0 } }
      }
      stubbed_client = Helpers::Aws.get_stubbed_client(aws_service: 'DynamoDB',
                                                      mocked_responses: responses)
      expect(Aws::DynamoDB::Client).to receive(:new).and_return(stubbed_client)
      expect {SlackAPI::Auth::save_temp_code(state: 'fake_state_id',
                                             code: 'fake_code')}.to_not raise_error
    end
  end

end
