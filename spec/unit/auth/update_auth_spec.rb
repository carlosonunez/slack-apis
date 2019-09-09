require 'spec_helper'

describe 'Updating authentication credentials', :wip do
  it 'Updates the bearer token associated with a given key' do
    payload = {
      :auth_code => 'fake_code_123'
    }
    expected_response = {
      :status => 'ok'
    }
    response = do_authenticated_http_put(endpoint: '/update_auth',
                                         payload: payload.to_json)
    expect(response.body).to eq(expected_response.to_json) 
  end
end
