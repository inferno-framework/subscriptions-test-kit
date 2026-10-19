require_relative 'subscription_status_endpoint'

module SubscriptionsTestKit
  class SubscriptionTypeStatusEndpoint < SubscriptionStatusEndpoint
    # Not inherited: SuiteEndpoint stores the format per class
    error_response_format :operation_outcome

    def requested_ids(inputs)
      inputs['id']
    end
  end
end
