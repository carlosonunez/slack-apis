$LOAD_PATH.unshift('./lib')
$LOAD_PATH.unshift('./vendor/bundle/ruby/**gems/**/lib') if Dir.exist? './vendor'

require 'slack-api'
require 'json'

# Retrieve tokens for autheticated users.
def get_token(event: {}, context: {})
  SlackAPI::Auth.get_slack_token(event: event)
end

# Begin the Slack OAuth flow manually.
def begin_authentication(event: {}, context: {})
  SlackAPI::Auth.begin_authentication_flow(event, client_id: ENV['SLACK_APP_CLIENT_ID'])
end

# Slack needs a callback URI to send its code too. This is that callback.
def handle_callback(event: {}, context: {})
  SlackAPI::Auth.handle_callback(event)
end

# health check. don't need request here...at least not yet.
def ping(event: {}, context: {})
  SlackAPI::Health.ping
end

# Set profile statuses
def status_set(event: {}, context: {})
  SlackAPI::Slack::Profile::Status.set!(event)
end

# Get profile statuses
def status_get(event: {}, context: {})
  SlackAPI::Slack::Profile::Status.get!(event)
end
