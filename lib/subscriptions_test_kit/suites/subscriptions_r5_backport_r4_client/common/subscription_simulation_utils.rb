# frozen_string_literal: true

module SubscriptionsTestKit
  module SubscriptionsR5BackportR4Client
    module SubscriptionSimulationUtils
      # Per the IG this should only be application/fhir+xml and application/fhir+json, however, Inferno (server suite)
      # can only handle application/json, so we'll allow that. Disallow XML for now.
      DEFAULT_MIME_TYPE = 'application/fhir+json'
      ALLOWED_MIME_TYPES = [DEFAULT_MIME_TYPE, 'application/json'].freeze

      def notification_bundle_input(test_result)
        JSON.parse(test_result.input_json).find { |i| i['name'] == 'notification_bundle' }['value']
      end

      def client_access_token_input(test_result)
        JSON.parse(test_result.input_json).find { |i| i['name'] == 'client_endpoint_access_token' }['value']
      end

      def derive_handshake_notification(notification_json, subscription_url)
        notification_bundle = FHIR.from_contents(notification_json)
        subscription_status = update_subscription_status(notification_bundle, subscription_url, 'requested', 0,
                                                         'handshake')
        subscription_status.parameter.delete(find_parameter(subscription_status, 'notification-event'))
        subscription_status.parameter.delete(find_parameter(subscription_status, 'error'))
        notification_bundle.entry = [find_subscription_status_entry(notification_bundle)]
        notification_bundle.timestamp = Time.now.utc.iso8601
        notification_bundle
      end

      def derive_event_notification(notification_json, subscription_url, event_count)
        notification_bundle = FHIR.from_contents(notification_json)
        update_subscription_status(notification_bundle, subscription_url, 'active', event_count, 'event-notification')
        notification_bundle.timestamp = Time.now.utc.iso8601
        notification_bundle
      end

      def derive_status_bundle(notification_json, subscription_url, status_code, event_count, request_url)
        notification_bundle = FHIR.from_contents(notification_json)
        subscription_status = update_subscription_status(notification_bundle, subscription_url, status_code,
                                                         event_count, 'query-status')
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

      def operation_outcome(severity, code, text = nil)
        oo = FHIR::OperationOutcome.new(issue: FHIR::OperationOutcome::Issue.new(severity:, code:))
        oo.issue.first.details = FHIR::CodeableConcept.new(text:) if text.present?
        oo
      end

      def find_subscription(test_session_id)
        request = requests_repo.tagged_requests(test_session_id, [SUBSCRIPTION_CREATE_TAG])&.find do |r|
          r.status == 201
        end
        return unless request

        begin
          FHIR.from_contents(request.response_body)
        rescue StandardError
          nil
        end
      end

      def determine_subscription_status_code(subscription_id)
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

      private

      def requests_repo
        @requests_repo ||= Inferno::Repositories::Requests.new
      end

      def notification_subscription_id(notification_json)
        notification_bundle = FHIR.from_contents(notification_json)
        subscription_status = find_subscription_status_entry(notification_bundle)&.resource
        subscription_url = find_parameter(subscription_status, 'subscription')&.valueReference
        subscription_url&.reference&.chomp('/')&.split('/')&.last
      end

      def update_subscription_status(notification_bundle, subscription_url, status_code, event_count, type)
        subscription_status_entry = find_subscription_status_entry(notification_bundle)
        subscription_status_entry.request = FHIR::Bundle::Entry::Request.new(method: 'POST',
                                                                             url: "#{subscription_url}/$status")
        subscription_status = subscription_status_entry&.resource
        set_subscription_reference(subscription_status, subscription_url)
        find_parameter(subscription_status, 'status')&.valueCode = status_code
        find_parameter(subscription_status, 'type')&.valueCode = type
        find_parameter(subscription_status, 'events-since-subscription-start')&.valueString = event_count.to_s
        subscription_status
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
    end
  end
end
