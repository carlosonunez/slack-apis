require 'spec_helper'
require 'ostruct'

describe "Handling fucking Slack OAuth" do
  it "Should save the OAuth code and state to DynamoDB", :unit do
    stubbed_client = Helpers::Aws::DynamoDB.get_stubbed_client
    allow_any_instance_of(Aws::DynamoDB::Client).to receive(:new)
                                                .and_return(stubbed_client)
    expect {SlackAPI::Auth::save_temp_code(state: 'fake_state_id',
                                          code: 'fake_code')}.to_not raise_error
  end
end
