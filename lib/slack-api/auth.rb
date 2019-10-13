require 'aws-sdk-dynamodb'

module SlackAPI
  module Auth
=begin
    Slack uses OAuth 2.0. Part of this workflow is providing the server (Slack)
    with a `redirect_uri` that the server can use to send a secret code that the
    client (this) sends back to retrieve a token.

    This method saves the code and the `state` parameter it's attached to
    into a DynamoDb table. Since these codes expire in ten minutes, there is
    little risk of someone logging in as someone else if someone somehow
    manages to obtain access to this database. The intent is that
    a call to the `continue_authorizing` endpoint pulls this code when given
    a `state` and completes the OAuth flow.

    In other words, this is a non-webserver way of authenticating via OAuth 2.0.

    In other _other_ words, this is probably terrible.
=end
    def self.save_temp_code(state:, code:)
      puts "save_temp_code: You ain't done!"
    end  
  end
end
