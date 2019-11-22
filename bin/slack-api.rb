#!/usr/bin/env ruby
$LOAD_PATH.unshift('./lib')
if Dir.exist? './vendor'
  $LOAD_PATH.unshift('./vendor/bundle/gems/**/lib')
end

require 'slack-api'
require 'json'

# Retrieve tokens for autheticated users.
def get_token(event: {}, context: {})
  SlackAPI::Auth.get_slack_token(context: context)
end

# Begin the Slack OAuth flow manually.
def begin_authentication(event: {}, context: {})
  SlackAPI::Auth.begin_authentication_flow(event, context, client_id: ENV['SLACK_APP_CLIENT_ID'])
end

# Slack needs a callback URI to send its code too. This is that callback.
def handle_callback(event: {}, context: {})
  SlackAPI::Auth.handle_callback(event, context)
end

# health check. don't need request here...at least not yet.
def ping(event: {}, context: {})
  SlackAPI::Health.ping
end
