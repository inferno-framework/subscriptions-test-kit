# frozen_string_literal: true

require_relative '../../common/subscription_simulation_utils'

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    module UpdateRequestLoading
      include SubscriptionSimulationUtils

      # Loads the update requests for the created Subscription that used the given HTTP method.
      # Skips if the client did not update the Subscription at all and omits if the client
      # only used a different method, since clients may update using either PUT or PATCH.
      def load_update_requests(verb)
        subscription = find_subscription(test_session_id)
        skip_if(subscription.nil?, 'No Subscription was created in this session')

        update_requests = requests_repo.tagged_requests(test_session_id, [SUBSCRIPTION_UPDATE_TAG, subscription.id])
        skip_if(update_requests.none?, %(
          Inferno did not receive an update (PUT or PATCH) request for the created Subscription with id
          #{subscription.id}
        ))

        requests.concat(update_requests.select { |r| r.verb.casecmp?(verb) })
        omit_if(requests.none?, "The client did not update the Subscription using #{verb.upcase}")

        subscription
      end
    end
  end
end
