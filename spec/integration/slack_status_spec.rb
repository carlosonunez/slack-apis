require 'spec_helper'

describe "Setting profile statuses" do
  it "Should save my status", :integration do
      restore_status_response =
        HTTParty.post("#{$api_gateway_url}/status?text=Old&emoji=:rocket:", {
          headers: { 'x-api-key': $test_api_key }
        })
      expect(restore_status_response.code.to_i).to eq 200
      response = HTTParty.post("#{$api_gateway_url}/status?text=A new status!&emoji=:cool:", {
        headers: { 'x-api-key': $test_api_key }
      })
      expect(response.code.to_i).to eq 200
      expect(JSON.parse(response.body)['status']).to eq 'ok'
      expect(JSON.parse(response.body)['changed']['new']).to eq ':cool: A new status!'
  end
end
