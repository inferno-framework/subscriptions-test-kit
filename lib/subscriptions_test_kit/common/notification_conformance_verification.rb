module SubscriptionsTestKit
  module NotificationConformanceVerification
    def no_error_verification(message)
      assert messages.none? { |msg| msg[:type] == 'error' }, message
    end

    def find_all_elems(resource_array, param_name)
      resource_array.select do |param|
        param.name == param_name
      end
    end

    def find_elem(resource_array, param_name)
      resource_array.find do |param|
        param.name == param_name
      end
    end

    def check_entry_request_and_response(entry, entry_num)
      if entry.request.blank?
        add_message('error', %(
          The `entry.request` field is mandatory for history Bundles, but was not included in entry #{entry_num}))
      end
      return unless entry.response.blank?

      add_message('error', %(
        The `entry.response` field is mandatory for history Bundles, but was not included in entry #{entry_num}))
    end

    def check_history_bundle_request_response(bundle, subscription_status_entry, subscription_id)
      check_entry_request_and_response(subscription_status_entry, 1)

      unless subscription_status_entry.request.present? &&
             (
               if subscription_id
                 subscription_status_entry.request.url.end_with?("Subscription/#{subscription_id}/$status")
               else
                 subscription_status_entry.request.url.match?(%r{Subscription/[^/]+/\$status\z})
               end
             )

        add_message('error',
                    'The SubscriptionStatus `request` SHALL be filled out to match a request to the $status operation')
      end

      bundle.entry.drop(1).each_with_index do |entry, index|
        check_entry_request_and_response(entry, index + 2)
      end
    end

    def parameters_verification(subscription_status)
      resource_type = subscription_status.resourceType
      if resource_type == 'Parameters'
        resource_is_valid?(resource: subscription_status, profile_url: 'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-subscription-status-r4')
      else
        add_message('error',
                    "Unexpected resource type: Expected `Parameters`. Got `#{resource_type}`")
      end
    end

    def notification_verification(notification_bundle, notification_type, subscription_id: nil, status: nil)
      assert_valid_json(notification_bundle)
      bundle = FHIR.from_contents(notification_bundle)
      assert bundle.present?, 'Not a FHIR resource'
      assert_resource_type(:bundle, resource: bundle)
      unless bundle.type == 'history'
        add_message('error', "Notification should be a history Bundle, instead was #{bundle.type}")
      end

      if bundle.entry.empty?
        add_message('error', 'Notification Bundle is empty.')
        return
      end
      subscription_status_entry = bundle.entry[0]

      check_history_bundle_request_response(bundle, subscription_status_entry, subscription_id)

      subscription_status = subscription_status_entry.resource
      parameters_verification(subscription_status)

      return unless subscription_status.respond_to?(:parameter)

      subscription_type = find_elem(subscription_status.parameter, 'type')

      unless subscription_type.valueCode == notification_type
        add_message('error', %(
            The Subscription resource should have it's `type` set to '#{notification_type}', was
            '#{subscription_type.valueCode}'))
      end

      return unless status.present?

      subscription_param_status = find_elem(subscription_status.parameter, 'status')
      return if subscription_param_status.valueCode == status

      add_message('error', %(
              The Subscription resource should have it's `status` set to '#{status}', was
              '#{subscription_param_status.valueCode}'))
    end

    def empty_notification_event_references(notification_events)
      empty_req_check = true
      notification_events.each do |notification_event|
        empty_req_check = notification_event.part.none? do |part|
          part.name == 'focus' || part.name == 'additional-context'
        end
        break unless empty_req_check
      end
      empty_req_check
    end

    def empty_notification_verification(bundle_entries, notification_events)
      unless bundle_entries.empty?
        add_message('error', %(
        When the content type is empty, notification bundles SHALL not contain Bundle.entry elements other than
        the SubscriptionStatus for the notification.))
      end

      if notification_events.empty?
        add_message('error', %(
          Events are required for empty notifications, but the SubscriptionStatus does not contain event-notifications
        ))
        return
      end

      empty_req_check = empty_notification_event_references(notification_events)
      return if empty_req_check

      add_message('error', %(
            When populating the SubscriptionStatus.notificationEvent structure for a notification with an empty
            payload, a server SHALL NOT include references to resources))
    end

    def verify_id_only_notification_bundle_entries(bundle_entries)
      bundle_entries.each do |entry|
        if entry.resource.present?
          add_message('error', 'Each Bundle.entry for id-only notification SHALL not contain the `resource` field')
        end
        if entry.fullUrl.blank?
          add_message('error', %(
            Each Bundle.entry for id-only notification SHALL contain a relevant resource URL in the fullUrl))
        end
      end
    end

    def verify_full_resource_notification_bundle_entries(bundle_entries)
      bundle_entries.each do |entry|
        resource_is_valid?(resource: entry.resource) if entry.resource.present?
      end
    end

    def check_bundle_entry_reference(bundle_entries, reference)
      check_full_url = reference.start_with?('urn:')

      referenced_entry = bundle_entries.find do |entry|
        if check_full_url
          reference == entry.fullUrl
        else
          reference.include?("#{entry.resource.resourceType}/#{entry.resource.id}")
        end
      end
      referenced_entry.present?
    end

    def check_notification_event_focus(focus_elem, bundle_entries)
      if focus_elem.blank?
        add_message('error', %(
            When the content type is `full-resource`, notification bundles SHALL include references to
            the appropriate focus resources in the SubscriptionStatus.notificationEvent.focus element))
      else
        unless check_bundle_entry_reference(bundle_entries, focus_elem.valueReference.reference)
          add_message('error', %(
            The Notification Bundle does not include a resource entry for the reference found in
            SubscriptionStatus.notificationEvent.focus with id #{focus_elem.valueReference.reference}))
        end
      end
    end

    def check_notification_event_additional_context(additional_context_list, bundle_entries)
      return if additional_context_list.empty?

      additional_context_list.each do |additional_context|
        next if check_bundle_entry_reference(bundle_entries, additional_context.valueReference.reference)

        add_message('error', %(
            The Notification Bundle does not include a resource entry for the reference found in
            SubscriptionStatus.notificationEvent.additional-context with id
            #{additional_context.valueReference.reference}))
      end
    end

    def full_resource_notification_event_parameter_verification(notification_events, bundle_entries)
      notification_events.each do |notification_event|
        focus_elem = find_elem(notification_event.part, 'focus')
        additional_context_list = find_all_elems(notification_event.part, 'additional-context')

        check_notification_event_focus(focus_elem, bundle_entries)
        check_notification_event_additional_context(additional_context_list, bundle_entries)
      end
    end

    def id_only_notification_event_parameter_verification(notification_events, criteria_resource_type)
      notification_events.each do |notification_event|
        focus_elem = find_elem(notification_event.part, 'focus')

        if focus_elem.blank?
          add_message('error', %(
              When the content type is `id-only`, notification bundles SHALL include references to
              the appropriate focus resources in the SubscriptionStatus.notificationEvent.focus element))
          break
        else
          break unless criteria_resource_type.present?

          unless focus_elem.valueReference.reference.include?(criteria_resource_type)
            add_message('error', %(
              The SubscriptionStatus.notificationEvent.focus should include a reference to a #{criteria_resource_type}
              resource, the resource type the Subscription is focused on))
            break
          end
        end
      end
    end

    def full_resource_notification_criteria_resource_check(bundle_entries, criteria_resource_type)
      relevant_resource = bundle_entries.any? do |entry|
        entry.resource.resourceType == criteria_resource_type || entry.request.url.include?(criteria_resource_type)
      end
      return if relevant_resource

      add_message('error', %(
          The notification bundle of type `full-resource` must include at least one #{criteria_resource_type}
          resource in the entry.resource element.))
    end

    def subscription_criteria(subscription)
      return unless subscription['_criteria']

      criteria_extension = subscription['_criteria']['extension'].find do |ext|
        ext['url'].ends_with?('/backport-filter-criteria')
      end
      criteria_extension['valueString'].split('?').first
    end

    def empty_event_notification_verification(notification_bundle)
      assert_valid_json(notification_bundle)
      bundle = FHIR.from_contents(notification_bundle)
      assert bundle.present?, 'Not a FHIR resource'

      subscription_status = bundle.entry[0].resource

      parameter_topic = find_elem(subscription_status.parameter, 'topic')
      if parameter_topic.present?
        add_message('warning',
                    'Parameters.parameter:topic.value[x]: This value SHOULD NOT be present when using empty payloads')
      end

      notification_events = find_all_elems(subscription_status.parameter, 'notification-event')
      bundle_entries = bundle.entry.drop(1)

      empty_notification_verification(bundle_entries, notification_events)
    end

    def full_resource_event_notification_verification(notification_bundle, criteria_resource_type)
      assert_valid_json(notification_bundle)
      bundle = FHIR.from_contents(notification_bundle)
      assert bundle.present?, 'Not a FHIR resource'

      subscription_status = bundle.entry[0].resource

      parameter_topic = find_elem(subscription_status.parameter, 'topic')
      if parameter_topic.blank?
        add_message('warning', %(
              Parameters.parameter:topic.value[x]: This value SHOULD be present when using full-resource payloads))
      end

      notification_events = find_all_elems(subscription_status.parameter, 'notification-event')
      bundle_entries = bundle.entry.drop(1)

      if criteria_resource_type.present?
        full_resource_notification_criteria_resource_check(bundle_entries, criteria_resource_type)
      end

      if notification_events.empty?
        add_message('error', %(
          The notification event parameter must be present in `full-resource` notification bundles.))
      else
        full_resource_notification_event_parameter_verification(notification_events, bundle_entries)
      end

      verify_full_resource_notification_bundle_entries(bundle_entries)
    end

    def id_only_event_notification_verification(notification_bundle, criteria_resource_type)
      assert_valid_json(notification_bundle)
      bundle = FHIR.from_contents(notification_bundle)
      assert bundle.present?, 'Not a FHIR resource'

      subscription_status = bundle.entry[0].resource

      parameter_topic = find_elem(subscription_status.parameter, 'topic')
      add_message('info', %(
        Parameters.parameter:topic.value[x] is #{'not ' if parameter_topic.blank?}populated in `id-only` Notification.
        This value MAY be present when using id-only payloads))

      notification_events = find_all_elems(subscription_status.parameter, 'notification-event')
      bundle_entries = bundle.entry.drop(1)

      if notification_events.empty?
        add_message('error', %(
            The notification event parameter must be present in `id-only` notification bundles.))
      else
        id_only_notification_event_parameter_verification(notification_events, criteria_resource_type)
      end

      verify_id_only_notification_bundle_entries(bundle_entries)
    end
  end
end
