#!/usr/bin/env ruby
$LOAD_PATH.unshift('./lib')
if Dir.exist? './vendor'
  $LOAD_PATH.unshift('./vendor/bundle/gems/**/lib')
end

require 'slack-api'
require 'json'

# health check. don't need request here...at least not yet.
def ping(event: {}, context: {})
  SlackAPI::Health.ping
end
