require 'json'

module SlackAPI
  module AWSHelpers
    class APIGateway
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

      def self.return_500(error_message:)
        self.send_response(code: 500, payload: { error: error_message })
      end
    end
  end
end
