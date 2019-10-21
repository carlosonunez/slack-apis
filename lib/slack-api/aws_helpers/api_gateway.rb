require 'json'

module SlackAPI
  module AWSHelpers
    class APIGateway
=begin
      Retrieves the endpoint from a request, optionally with a part of its path removed.
=end
      def self.get_endpoint(event, path_to_remove: '/auth')
        # TODO: Fix TypeError Hash into String errror from API Gateway.
        path = event['requestContext']['path'] || raise("Path not found in event.")
        path_subbed = path.gsub!(path_to_remove,'')
        host = event['headers']['Host'] || raise("Host not found in event.")
        "#{host}#{path_subbed}"
      end

      def self.send_response(code:, payload:)
        raise "Payload must be a Hash" if !payload.nil? and payload.class != Hash
        {
          :statusCode => code,
          :body => payload.to_json
        }
      end
      def self.return_200(body: nil, json: {})
        raise "JSON can't be empty" if body.nil? and json.empty?
        if !json.empty?
          self.send_response(code: 200, payload: json)
        else
          self.send_response(code: 200, payload: { message: body })
        end
      end

      def self.return_403(body:)
        self.send_response(code: 403, payload: { message: body })
      end
    end
  end
end
