# frozen_string_literal: true

require_relative '../../common/subscription_simulation_utils'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    module UpdateRequestLoading
      include SubscriptionSimulationUtils

      # Loads the update requests for the created Subscription that used the given HTTP method. Requests that
      # targeted other ids are ignored. Skips if the client did not send any such requests.
      def load_update_requests(verb)
        subscription = find_subscription(test_session_id)
        skip_if(subscription.nil?, 'No Subscription was created in this session')

        update_requests = requests_repo.tagged_requests(test_session_id, [SUBSCRIPTION_UPDATE_TAG, subscription.id])
        requests.concat(update_requests.select { |r| r.verb.casecmp?(verb) })
        skip_if(requests.none?, %(
          Inferno did not receive a #{verb.upcase} request for the created Subscription with id #{subscription.id}
        ))

        subscription
      end

      # Verifies each loaded update request, using the given block for the checks specific to the HTTP method.
      # Every request must have been accepted by Inferno and pass those checks. Each message is prefixed with
      # the number of the request that it is about.
      def verify_update_requests(&)
        requests.each.with_index(1) do |update_request, request_number|
          verify_update_request(update_request, request_number, &)
        end

        no_error_verification("Subscription #{requests.first.verb.upcase} update request is not conformant.")
      end

      def verify_update_request(update_request, request_number)
        first_message_index = messages.length
        begin
          assert(update_request.status == 200, %(
            Inferno could not apply the request (status #{update_request.status}):
            #{error_response_text(update_request.response_body)}
          ))
          yield update_request
        rescue Inferno::Exceptions::AssertionException => e
          add_message('error', e.message)
        end

        messages[first_message_index..].each do |message|
          message[:message] = "Request #{request_number}: #{message[:message]}"
        end
      end

      def error_response_text(response_body)
        outcome = JSON.parse(response_body)
        (outcome.dig('issue', 0, 'details', 'text') if outcome.is_a?(Hash)) || 'no details provided'
      rescue JSON::ParserError, TypeError
        'no details provided'
      end
    end
  end
end
