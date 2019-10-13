require 'spec_helper'
require 'ostruct'

describe "Handling fucking Slack OAuth" do
  it "Should save the OAuth code and state to DynamoDB", :unit do
    responses = {
      put_item: { consumed_capacity: { table_name: 'slack_api_temp_oauth_codes' } },
      list_tables: { table_names: [ "slack_api_temp_oauth_codes" ] },
      create_table: { table_description: { item_count: 0 } }
    }
    stubbed_client = Helpers::Aws::DynamoDB.get_stubbed_client(
      mocked_responses: responses
    )
    expect(Aws::DynamoDB::Client).to receive(:new).and_return(stubbed_client)
    expect {SlackAPI::Auth::save_temp_code(state: 'fake_state_id',
                                           code: 'fake_code')}.to_not raise_error
  end
end
