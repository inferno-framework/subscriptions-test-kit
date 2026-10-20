# frozen_string_literal: true

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    module SubscriptionSimulationUtils
      # Per the IG this should only be application/fhir+xml and application/fhir+json,
      # application/json, so we'll allow that. Disallow XML for now.
      DEFAULT_MIME_TYPE = 'application/fhir+json'
      ALLOWED_MIME_TYPES = [DEFAULT_MIME_TYPE, 'application/json'].freeze
      JSON_PATCH_MIME_TYPE = 'application/json-patch+json'

      def notification_bundle_input(test_result)
        input = JSON.parse(test_result.input_json).find { |i| i['name'] == 'notification_bundle' }
        return input['value'] if input.present?

        # Tests that wait after the Subscription workflow (e.g., update and delete) do not take the notification
        # bundle as an input, so fall back to the value stored for the session.
        Inferno::Repositories::SessionData.new.load(test_session_id: test_result.test_session_id,
                                                    name: 'notification_bundle')
      end

      def client_access_token_input(test_result)
        JSON.parse(test_result.input_json).find { |i| i['name'] == 'client_endpoint_access_token' }['value']
      end

      def derive_handshake_notification(notification_json, subscription_url, subscription_topic)
        notification_bundle = FHIR.from_contents(notification_json)
        subscription_status = update_subscription_status(notification_bundle, subscription_url, subscription_topic,
                                                         'requested', 0, 'handshake')
        subscription_status.parameter.delete(find_parameter(subscription_status, 'notification-event'))
        subscription_status.parameter.delete(find_parameter(subscription_status, 'error'))
        notification_bundle.entry = [find_subscription_status_entry(notification_bundle)]
        notification_bundle.timestamp = Time.now.utc.iso8601
        notification_bundle
      end

      def derive_event_notification(notification_json, subscription_url, subscription_topic, event_count)
        notification_timestamp = Time.now.utc.iso8601
        notification_bundle = FHIR.from_contents(notification_json)
        subscription_status = update_subscription_status(notification_bundle, subscription_url, subscription_topic,
                                                         'active', event_count, 'event-notification')
        update_event_timestamps(subscription_status, notification_timestamp)
        notification_bundle.timestamp = notification_timestamp
        notification_bundle
      end

      def derive_status_bundle(notification_json, subscription_url, subscription_topic,
                               status_code, event_count, request_url)
        notification_bundle = FHIR.from_contents(notification_json)
        subscription_status = update_subscription_status(notification_bundle, subscription_url, subscription_topic,
                                                         status_code, event_count, 'query-status')
        subscription_status.parameter.delete(find_parameter(subscription_status, 'notification-event'))
        subscription_status_entry = find_subscription_status_entry(notification_bundle)
        FHIR::Bundle.new(
          entry: FHIR::Bundle::Entry.new(
            fullUrl: subscription_status_entry.fullUrl,
            resource: subscription_status,
            search: FHIR::Bundle::Entry::Search.new(mode: 'match', score: 1)
          ),
          link: FHIR::Bundle::Link.new(relation: 'self', url: request_url),
          total: 1,
          type: 'searchset',
          timestamp: Time.now.utc.iso8601
        )
      end

      def empty_status_bundle(request_url)
        FHIR::Bundle.new(
          link: FHIR::Bundle::Link.new(relation: 'self', url: request_url),
          total: 0,
          type: 'searchset',
          timestamp: Time.now.utc.iso8601
        )
      end

      def operation_outcome(severity, code, text = nil)
        oo = FHIR::OperationOutcome.new(issue: FHIR::OperationOutcome::Issue.new(severity:, code:))
        oo.issue.first.details = FHIR::CodeableConcept.new(text:) if text.present?
        oo
      end

      def find_subscription(test_session_id, as_json: false)
        request = requests_repo.tagged_requests(test_session_id, [SUBSCRIPTION_CREATE_TAG])&.find do |r|
          r.status == 201
        end
        return unless request

        parse_subscription(request.response_body, as_json:)
      end

      # The created Subscription as modified by any subsequent successful updates, or nil if it has been deleted.
      # Updates and deletes are only accepted during the update and delete interaction test (see
      # subscription_change_allowed?), so each run of that test starts again from the created Subscription.
      def find_current_subscription(test_session_id)
        subscription = find_subscription(test_session_id)
        return if subscription.nil?

        # Only updates and deletes are tagged with the Subscription id, so load them together
        delete_requests, update_requests = requests_repo.tagged_requests(test_session_id, [subscription.id])
          .partition { |r| r.tags.include?(SUBSCRIPTION_DELETE_TAG) }
        return if delete_requests.any? { |r| r.status.between?(200, 299) }

        update_request = update_requests.reverse.find { |r| r.status == 200 }
        return subscription unless update_request

        parse_subscription(update_request.response_body)
      end

      # For endpoints: whether the waiting test accepts changes (updates and deletes) to the Subscription, which
      # a test indicates with the accepts_subscription_changes config option
      def subscription_change_allowed?
        test.config.options[:accepts_subscription_changes] == true
      end

      # For endpoints: reject a change to the Subscription requested while a different test is waiting
      def reject_subscription_change
        fhir_error_response(422, 'business-rule', %(
          Inferno only accepts Subscription updates and deletes during the Demonstrate Subscription Update and
          Deletion tests.
        ).squish)
      end

      # For endpoints: respond with an error status and an OperationOutcome describing the error
      def fhir_error_response(status, code, text = nil)
        response.format = :json
        response.status = status
        response.body = operation_outcome('error', code, text).to_json
      end

      # Inferno does not act on status changes requested by the client, except to honor requests to turn
      # the Subscription off
      def current_subscription_status_code(subscription)
        return 'off' if subscription.status == 'off'

        determine_subscription_status_code(subscription.id)
      end

      # Memoized because the handshakes do not change while an endpoint responds to a request
      def determine_subscription_status_code(subscription_id)
        @subscription_status_codes ||= {}
        @subscription_status_codes[subscription_id] ||= handshake_status_code(subscription_id)
      end

      def handshake_status_code(subscription_id)
        handshakes = requests_repo.tagged_requests(test_run.test_session_id, [REST_HOOK_HANDSHAKE_NOTIFICATION_TAG])
        handshake = handshakes.filter { |h| notification_subscription_id(h.request_body) == subscription_id }.last

        if handshake.nil?
          'requested'
        elsif handshake.status.between?(200, 299)
          'active'
        else
          'error'
        end
      end

      def determine_event_count(test_session_id)
        requests_repo.tagged_requests(test_session_id, [REST_HOOK_EVENT_NOTIFICATION_TAG]).count
      end

      def actual_mime_type(subscription)
        if ALLOWED_MIME_TYPES.include?(subscription&.channel&.payload)
          subscription&.channel&.payload
        else
          DEFAULT_MIME_TYPE
        end
      end

      # Checks that Inferno is able to simulate the requested Subscription.
      # Returns an OperationOutcome describing the problem, or nil if the Subscription is supported.
      def verify_subscription(subscription)
        unless subscription.is_a? FHIR::Subscription
          return operation_outcome('error', 'invalid', 'No recognized R4 Subscription in request body')
        end

        unless subscription.channel&.type == 'rest-hook'
          return operation_outcome('error', 'business-rule', 'channel.type must be rest-hook')
        end

        unless valid_channel_endpoint?(subscription.channel&.endpoint)
          return operation_outcome('error', 'value', 'channel.endpoint is not recognized as a conformant URL')
        end

        heartbeat_period = find_heartbeat_period(subscription)
        operation_outcome('error', 'not-supported', 'heartbeatPeriod is not supported') unless heartbeat_period.nil?
      end

      private

      def parse_subscription(subscription_json, as_json: false)
        if as_json
          # needed to access primitive extensions
          JSON.parse(subscription_json)
        else
          FHIR.from_contents(subscription_json)
        end
      rescue StandardError
        nil
      end

      def find_heartbeat_period(subscription)
        subscription.channel&.extension&.find do |e|
          e.url == 'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-heartbeat-period'
        end
      end

      def valid_channel_endpoint?(url)
        uri = URI.parse(url)
        %w[http https].include?(uri.scheme)
      rescue URI::InvalidURIError
        false
      end

      def requests_repo
        @requests_repo ||= Inferno::Repositories::Requests.new
      end

      def notification_subscription_id(notification_json)
        notification_bundle = FHIR.from_contents(notification_json)
        subscription_status = find_subscription_status_entry(notification_bundle)&.resource
        subscription_url = find_parameter(subscription_status, 'subscription')&.valueReference
        return unless subscription_url&.reference.present?

        subscription_url.reference.chomp('/').split('/').last
      end

      def update_subscription_status(notification_bundle, subscription_url, subscription_topic, status_code,
                                     event_count, type)
        subscription_status_entry = find_subscription_status_entry(notification_bundle)
        subscription_status_entry.request = FHIR::Bundle::Entry::Request.new(method: 'GET',
                                                                             url: "#{subscription_url}/$status")
        subscription_status_entry.response = FHIR::Bundle::Entry::Response.new(status: '200')
        subscription_status = subscription_status_entry&.resource
        set_subscription_reference(subscription_status, subscription_url)
        find_parameter(subscription_status, 'topic')&.valueCanonical = subscription_topic
        find_parameter(subscription_status, 'status')&.valueCode = status_code
        find_parameter(subscription_status, 'type')&.valueCode = type
        find_parameter(subscription_status, 'events-since-subscription-start')&.valueString = event_count.to_s
        subscription_status
      end

      def update_event_timestamps(subscription_status, timestamp = nil)
        timestamp = Time.now.utc.iso8601 unless timestamp.present?
        event_list = find_all_parameters(subscription_status, 'notification-event')
        event_list.each do |event|
          event.part.find { |part| part.name == 'timestamp' }&.valueInstant = timestamp
        end
      end

      def find_subscription_status_entry(notification_bundle)
        notification_bundle.entry.find do |e|
          e.resource&.resourceType == 'Parameters' && e.resource.parameter&.any? { |p| p.name == 'subscription' }
        end
      end

      def set_subscription_reference(subscription_status, subscription_url)
        subscription = find_parameter(subscription_status, 'subscription')
        unless subscription
          subscription = FHIR::Parameters::Parameter.new(name: 'subscription')
          subscription_status.parameter.unshift(subscription)
        end

        subscription.valueReference = FHIR::Reference.new(reference: subscription_url)
        subscription
      end

      def find_parameter(subscription_status, parameter_name)
        subscription_status.parameter&.find { |p| p.name == parameter_name }
      end

      def find_all_parameters(subscription_status, parameter_name)
        subscription_status.parameter&.select { |p| p.name == parameter_name }
      end
    end
  end
end
