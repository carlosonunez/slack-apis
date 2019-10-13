require 'spec_helper'
require 'ostruct'

describe "Handling fucking Slack OAuth" do
  context "Not authenticated yet" do
    it "Should give the user a prompt to initialize the auth process", :unit do
      expected_message = <<-MESSAGE
You will need to authenticate into Slack first. To do so, click on or copy/paste
the link below, then go to /finish_authentication once done:
https://slack.com/oauth/authorize?client_id=fake&\
scope=users.profile:write,users.write,users.profile:read&\
redirect_uri=https://example.fake/callback&\
state=api-key
MESSAGE
      expected_response = {
        statusCode: 200,
        body: { message: expected_message }.to_json
      }
      expect(SlackAPI::Auth::begin_authentication_flow).to eq expected_response
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
