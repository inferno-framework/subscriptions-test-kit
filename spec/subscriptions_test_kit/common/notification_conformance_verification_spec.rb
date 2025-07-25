require_relative '../../../lib/subscriptions_test_kit/common/notification_conformance_verification'

RSpec.describe SubscriptionsTestKit::NotificationConformanceVerification, :runnable do
  let(:suite_id) { 'subscriptions_r5_backport_r4_server' }
  let(:results_repo) { Inferno::Repositories::Results.new }

  let(:full_resource_notification_bundle) do
    JSON.parse(File.read(File.join(
                           __dir__, '../..', 'fixtures', 'full_resource_notification_bundle_example.json'
                         )))
  end

  let(:empty_notification_bundle) do
    JSON.parse(File.read(File.join(
                           __dir__, '../..', 'fixtures', 'empty_notification_bundle_example.json'
                         )))
  end

  let(:id_only_notification_bundle) do
    JSON.parse(File.read(File.join(
                           __dir__, '../..', 'fixtures', 'id_only_notification_bundle_example.json'
                         )))
  end

  let(:operation_outcome_success) do
    {
      outcomes: [{
        issues: []
      }],
      sessionId: test_session.id
    }
  end

  let(:operation_outcome_failure) do
    {
      outcomes: [{
        issues: [{
          level: 'ERROR',
          message: 'Resource does not conform to profile'
        }]
      }],
      sessionId: test_session.id
    }
  end

  let(:subscription_id) { '123' }

  def entity_result_message(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:message)
      .join(' ')
  end

  def entity_result_message_type(runnable)
    results_repo.current_results_for_test_session_and_runnables(test_session.id, [runnable])
      .first
      .messages
      .map(&:type)
      .first
  end

  describe 'Notification Verification' do
    let(:test) do
      Class.new(Inferno::Test) do
        include SubscriptionsTestKit::NotificationConformanceVerification
        fhir_resource_validator do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.uv.subscriptions-backport#1.1.0')
        end

        input :notification_bundle, :notification_type, :subscription_id
        input :status,
              optional: true

        run do
          notification_verification(notification_bundle, notification_type, subscription_id:, status:)
          no_error_verification('There were verification errors')
        end
      end
    end

    before do
      Inferno::Repositories::Tests.new.insert(test)
    end

    it 'passes if conformant notification bundle passed in' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      result = run(test, notification_bundle: full_resource_notification_bundle.to_json,
                         notification_type: 'event-notification', subscription_id:)
      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made
    end

    it 'passes if conformant notification bundle passed in with correct status argument' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      result = run(test, notification_bundle: full_resource_notification_bundle.to_json,
                         notification_type: 'event-notification', subscription_id:, status: 'active')
      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made
    end

    it 'fails if passed in bundle is not valid JSON' do
      result = run(test, notification_bundle: '[[',
                         notification_type: 'event-notification', subscription_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Invalid JSON. ')
    end

    it 'fails if passed in bundle is not a FHIR resource' do
      result = run(test, notification_bundle: { field: 'example' }.to_json,
                         notification_type: 'event-notification', subscription_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Not a FHIR resource')
    end

    it 'fails if passed in bundle is not a Bundle resource' do
      full_resource_notification_bundle['resourceType'] = 'Patient'
      result = run(test, notification_bundle: full_resource_notification_bundle.to_json,
                         notification_type: 'event-notification', subscription_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Unexpected resource type: expected Bundle, but received Patient')
    end

    it 'fails if passed in bundle not a history type Bundle' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      full_resource_notification_bundle['type'] = 'collection'
      result = run(test, notification_bundle: full_resource_notification_bundle.to_json,
                         notification_type: 'event-notification', subscription_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to eq('Notification should be a history Bundle, instead was collection')
      expect(verification_request).to have_been_made
    end

    it 'fails if passed in Bundle is empty' do
      full_resource_notification_bundle['entry'] = []
      result = run(test, notification_bundle: full_resource_notification_bundle.to_json,
                         notification_type: 'event-notification', subscription_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to eq('Notification Bundle is empty.')
    end

    it 'fails if SubscriptionStatus does not have the `request` field populated' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      full_resource_notification_bundle['entry'].first.delete('request')
      result = run(test, notification_bundle: full_resource_notification_bundle.to_json,
                         notification_type: 'event-notification', subscription_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'The `entry.request` field is mandatory for history Bundles, but was not included'
      )
      expect(verification_request).to have_been_made
    end

    it 'fails if SubscriptionStatus does not have the `response` field populated' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      full_resource_notification_bundle['entry'].first.delete('response')
      result = run(test, notification_bundle: full_resource_notification_bundle.to_json,
                         notification_type: 'event-notification', subscription_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'The `entry.response` field is mandatory for history Bundles, but was not included'
      )
      expect(verification_request).to have_been_made
    end

    it 'fails if SubscriptionStatus does not have the $status operation url in the `request` field' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      full_resource_notification_bundle['entry'].first['request']['url'] = 'https://fhirserver.org/fhir/Subscription/123/$wrongoperation'
      result = run(test, notification_bundle: full_resource_notification_bundle.to_json,
                         notification_type: 'event-notification', subscription_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to eq(
        'The SubscriptionStatus `request` SHALL be filled out to match a request to the $status operation'
      )
      expect(verification_request).to have_been_made
    end

    it 'fails if entry in Bundle does not have the `request` field populated' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      full_resource_notification_bundle['entry'].last.delete('request')
      result = run(test, notification_bundle: full_resource_notification_bundle.to_json,
                         notification_type: 'event-notification', subscription_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'The `entry.request` field is mandatory for history Bundles, but was not included'
      )
      expect(verification_request).to have_been_made
    end

    it 'fails if entry in Bundle does not have the `response` field populated' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      full_resource_notification_bundle['entry'].last.delete('response')
      result = run(test, notification_bundle: full_resource_notification_bundle.to_json,
                         notification_type: 'event-notification', subscription_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'The `entry.response` field is mandatory for history Bundles, but was not included'
      )
      expect(verification_request).to have_been_made
    end

    it 'fails if first entry in Bundle is not a SubscriptionStatus Parameters resource' do
      full_resource_notification_bundle['entry'].first['resource']['resourceType'] = 'Patient'
      result = run(test, notification_bundle: full_resource_notification_bundle.to_json,
                         notification_type: 'event-notification', subscription_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to eq(
        'Unexpected resource type: Expected `Parameters`. Got `Patient`'
      )
    end

    it 'fails if SubscriptionStatus Parameters resource is not conformant' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_failure.to_json).then
        .to_return(status: 200, body: operation_outcome_success.to_json)

      result = run(test, notification_bundle: full_resource_notification_bundle.to_json,
                         notification_type: 'event-notification', subscription_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'Resource does not conform to profile'
      )
      expect(verification_request).to have_been_made
    end

    it 'fails if SubscriptionStatus type is not set to the notification type passed in' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      result = run(test, notification_bundle: full_resource_notification_bundle.to_json,
                         notification_type: 'heartbeat', subscription_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        "The Subscription resource should have it's `type` set to 'heartbeat', was"
      )
      expect(verification_request).to have_been_made
    end

    it 'fails if status argument is passed in but does not equal the status of the SubscriptionStatus' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      result = run(test, notification_bundle: full_resource_notification_bundle.to_json,
                         notification_type: 'heartbeat', subscription_id:, status: 'requested')
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        "The Subscription resource should have it's `status` set to 'requested', was"
      )
      expect(verification_request).to have_been_made
    end
  end

  describe 'Full-Resource Notification-Event Parameter Verification' do
    let(:test) do
      Class.new(Inferno::Test) do
        include SubscriptionsTestKit::NotificationConformanceVerification
        fhir_resource_validator do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.uv.subscriptions-backport#1.1.0')
        end

        input :notification_bundle

        run do
          notification_bundle_resource = FHIR.from_contents(notification_bundle)
          notification_event = notification_bundle_resource.entry.first.resource.parameter.last
          notification_events = [notification_event]

          bundle_entries = notification_bundle_resource.entry.drop(1)

          full_resource_notification_event_parameter_verification(notification_events, bundle_entries)
          no_error_verification('There were verification errors')
        end
      end
    end

    before do
      Inferno::Repositories::Tests.new.insert(test)
    end

    it 'passes if array of conformant event-notifications passed in' do
      result = run(test, notification_bundle: full_resource_notification_bundle.to_json)
      expect(result.result).to eq('pass')
    end

    it 'fails if event-notification focus field is blank' do
      full_resource_notification_bundle['entry'].first['resource']['parameter'].last['part'].pop

      result = run(test, notification_bundle: full_resource_notification_bundle.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'When the content type is `full-resource`, notification bundles SHALL include references to'
      )
    end

    it 'fails if event-notification focus contains a reference not found in the Bundle entries' do
      focus = full_resource_notification_bundle['entry'].first['resource']['parameter'].last['part'].last
      focus['valueReference']['reference'] = 'https://fhirserver.org/fhir/Patient/86009987-eabe-42bf-8c02-b112b18cb616'

      result = run(test, notification_bundle: full_resource_notification_bundle.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'The Notification Bundle does not include a resource entry for the reference found in'
      )
    end

    it 'succeeds if event-notification focus uses a uuid (urn reference)' do
      focus = full_resource_notification_bundle['entry'].first['resource']['parameter'].last['part'].last
      focus['valueReference']['reference'] = 'urn:uri:86009987-eabe-42bf-8c02-b112b18cb616'
      full_resource_notification_bundle['entry'][1]['fullUrl'] = 'urn:uri:86009987-eabe-42bf-8c02-b112b18cb616'

      result = run(test, notification_bundle: full_resource_notification_bundle.to_json)
      expect(result.result).to eq('pass')
    end

    it 'fails if event-notification additional-context contains a reference not found in the Bundle entries' do
      additional_context = {
        name: 'additional-context',
        valueReference: {
          reference: 'https://fhirserver.org/fhir/Patient/86009987-eabe-42bf-8c02-b112b18cb616'
        }
      }
      full_resource_notification_bundle['entry'].first['resource']['parameter'].last['part'].append(additional_context)

      result = run(test, notification_bundle: full_resource_notification_bundle.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'The Notification Bundle does not include a resource entry for the reference found in'
      )
    end
  end

  describe 'Id-Only Notification-Event Parameter Verification' do
    let(:test) do
      Class.new(Inferno::Test) do
        include SubscriptionsTestKit::NotificationConformanceVerification
        fhir_resource_validator do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.uv.subscriptions-backport#1.1.0')
        end

        input :notification_bundle

        run do
          notification_bundle_resource = FHIR.from_contents(notification_bundle)
          notification_event = notification_bundle_resource.entry.first.resource.parameter.last
          notification_events = [notification_event]

          id_only_notification_event_parameter_verification(notification_events, nil)
          no_error_verification('There were verification errors')
        end
      end
    end

    before do
      Inferno::Repositories::Tests.new.insert(test)
    end

    it 'passes if array of conformant event-notifications passed in' do
      result = run(test, notification_bundle: id_only_notification_bundle.to_json)
      expect(result.result).to eq('pass')
    end

    it 'fails if event-notification focus field is blank' do
      id_only_notification_bundle['entry'].first['resource']['parameter'].last['part'].pop

      result = run(test, notification_bundle: id_only_notification_bundle.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'When the content type is `id-only`, notification bundles SHALL include references to'
      )
    end
  end

  describe 'Empty Event Notification Verification' do
    let(:test) do
      Class.new(Inferno::Test) do
        include SubscriptionsTestKit::NotificationConformanceVerification
        fhir_resource_validator do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.uv.subscriptions-backport#1.1.0')
        end

        input :notification_bundle

        run do
          empty_event_notification_verification(notification_bundle)
          no_error_verification('There were verification errors')
        end
      end
    end

    before do
      Inferno::Repositories::Tests.new.insert(test)
    end

    it 'passes if conformant empty notification bundle passed in' do
      result = run(test, notification_bundle: empty_notification_bundle.to_json)
      expect(result.result).to eq('pass')
    end

    it 'fails if empty notification bundle is not valid JSON' do
      result = run(test, notification_bundle: '[[')
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Invalid JSON. ')
    end

    it 'fails if empty notification bundle is not a FHIR resource' do
      result = run(test, notification_bundle: { field: 'example' }.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Not a FHIR resource')
    end

    it 'produces warning if empty notification bundle contains parameter.topic field' do
      result = run(test, notification_bundle: empty_notification_bundle.to_json)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(
        'Parameters.parameter:topic.value[x]: This value SHOULD NOT be present when using empty payloads'
      )
      expect(entity_result_message_type(test)).to eq('warning')
    end

    it 'fails if empty notification bundle contains additional entries in Bundle' do
      empty_notification_bundle['entry'].append(full_resource_notification_bundle['entry'].last)
      result = run(test, notification_bundle: empty_notification_bundle.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'When the content type is empty, notification bundles SHALL not contain Bundle.entry elements other than'
      )
    end

    it 'fails if SubscriptionStatus does not contain any event-notifications' do
      empty_notification_bundle['entry'].first['resource']['parameter'].pop
      result = run(test, notification_bundle: empty_notification_bundle.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'Events are required for empty notifications, but the SubscriptionStatus does not contain event-notifications'
      )
    end

    it 'fails if SubscriptionStatus event-notifications array contains the `focus` element' do
      focus_entry = full_resource_notification_bundle['entry'].first['resource']['parameter'].last['part'].last
      empty_notification_bundle['entry'].first['resource']['parameter'].last['part'].append(focus_entry)

      result = run(test, notification_bundle: empty_notification_bundle.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'When populating the SubscriptionStatus.notificationEvent structure for an event notification with an empty'
      )
    end
  end

  describe 'Full Resource Event Notification Verification' do
    let(:test) do
      Class.new(Inferno::Test) do
        include SubscriptionsTestKit::NotificationConformanceVerification
        fhir_resource_validator do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.uv.subscriptions-backport#1.1.0')
        end

        input :notification_bundle

        run do
          full_resource_event_notification_verification(notification_bundle, nil)
          no_error_verification('There were verification errors')
        end
      end
    end

    before do
      Inferno::Repositories::Tests.new.insert(test)
    end

    it 'passes if conformant full-resource notification bundle passed in' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      result = run(test, notification_bundle: full_resource_notification_bundle.to_json)
      expect(result.result).to eq('pass')
      expect(verification_request).to have_been_made
    end

    it 'fails if full-resource notification bundle is not valid JSON' do
      result = run(test, notification_bundle: '[[')
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Invalid JSON. ')
    end

    it 'fails if full-resource notification bundle is not a FHIR resource' do
      result = run(test, notification_bundle: { field: 'example' }.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Not a FHIR resource')
    end

    it 'produces warning if full-resource notification bundle does not contain parameter.topic field' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      full_resource_notification_bundle['entry'].first['resource']['parameter'].delete_at(1)
      result = run(test, notification_bundle: full_resource_notification_bundle.to_json)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(
        'This value SHOULD be present when using full-resource payloads'
      )
      expect(entity_result_message_type(test)).to eq('warning')
      expect(verification_request).to have_been_made
    end

    it 'fails if SubscriptionStatus does not contain any event-notifications' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_success.to_json)

      full_resource_notification_bundle['entry'].first['resource']['parameter'].pop
      result = run(test, notification_bundle: full_resource_notification_bundle.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'The notification event parameter must be present in `full-resource` notification bundles.'
      )
      expect(verification_request).to have_been_made
    end

    it 'fails if any entries in full-resource notification bundle are not conformant' do
      verification_request = stub_request(:post, validation_url)
        .to_return(status: 200, body: operation_outcome_failure.to_json)

      result = run(test, notification_bundle: full_resource_notification_bundle.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'Resource does not conform to profile'
      )
      expect(verification_request).to have_been_made
    end
  end

  describe 'Id Only Event Notification Verification' do
    let(:test) do
      Class.new(Inferno::Test) do
        include SubscriptionsTestKit::NotificationConformanceVerification
        fhir_resource_validator do
          url ENV.fetch('FHIR_RESOURCE_VALIDATOR_URL')

          cli_context do
            txServer nil
            displayWarnings true
            disableDefaultResourceFetcher true
          end

          igs('hl7.fhir.uv.subscriptions-backport#1.1.0')
        end

        input :notification_bundle

        run do
          id_only_event_notification_verification(notification_bundle, nil)
          no_error_verification('There were verification errors')
        end
      end
    end

    before do
      Inferno::Repositories::Tests.new.insert(test)
    end

    it 'passes if conformant id-only notification bundle passed in' do
      result = run(test, notification_bundle: id_only_notification_bundle.to_json)
      expect(result.result).to eq('pass')
    end

    it 'fails if id-only notification bundle is not valid JSON' do
      result = run(test, notification_bundle: '[[')
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Invalid JSON. ')
    end

    it 'fails if id-only notification bundle is not a FHIR resource' do
      result = run(test, notification_bundle: { field: 'example' }.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Not a FHIR resource')
    end

    it 'produces info message if id-only notification bundle contains parameter.topic field' do
      result = run(test, notification_bundle: id_only_notification_bundle.to_json)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(
        'is populated in `id-only` Notification'
      )
      expect(entity_result_message_type(test)).to eq('info')
    end

    it 'produces info message if id-only notification bundle does not contain parameter.topic field' do
      id_only_notification_bundle['entry'].first['resource']['parameter'].delete_at(1)
      result = run(test, notification_bundle: id_only_notification_bundle.to_json)
      expect(result.result).to eq('pass')
      expect(entity_result_message(test)).to match(
        'is not populated in `id-only` Notification'
      )
      expect(entity_result_message_type(test)).to eq('info')
    end

    it 'fails if SubscriptionStatus does not contain any event-notifications' do
      id_only_notification_bundle['entry'].first['resource']['parameter'].pop
      result = run(test, notification_bundle: id_only_notification_bundle.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'The notification event parameter must be present in `id-only` notification bundles.'
      )
    end

    it 'fails if id-only bundle contains an entry with a resource' do
      entry_resource = full_resource_notification_bundle['entry'].last['resource']
      id_only_notification_bundle['entry'].last['resource'] = entry_resource
      result = run(test, notification_bundle: id_only_notification_bundle.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'Each Bundle.entry for id-only notification SHALL not contain the `resource` field'
      )
    end

    it 'fails if id-only bundle contains an entry without a full url' do
      id_only_notification_bundle['entry'].last.delete('fullUrl')
      result = run(test, notification_bundle: id_only_notification_bundle.to_json)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('There were verification errors')
      expect(entity_result_message(test)).to match(
        'Each Bundle.entry for id-only notification SHALL contain a relevant resource URL in the fullUrl'
      )
    end
  end

  describe 'Notification Header Verification' do
    let(:subscription_resource) do
      JSON.parse(File.read(File.join(
                             __dir__, '../..', 'fixtures', 'subscription_resource_example.json'
                           )))
    end

    let(:test) do
      Class.new(Inferno::Test) do
        include SubscriptionsTestKit::NotificationConformanceVerification

        input :subscription

        run do
          headers = [
            Inferno::Entities::Header.new(
              type: 'request',
              name: 'Authorization',
              value: 'Bearer SAMPLE_TOKEN'
            ),
            Inferno::Entities::Header.new(
              type: 'request',
              name: 'content-type',
              value: 'application/fhir+json'
            )
          ]
          notification_header_verification(headers, JSON.parse(subscription))
          no_error_verification('There were verification errors')
        end
      end
    end

    before do
      Inferno::Repositories::Tests.new.insert(test)
    end

    it 'passes when the right headers are in the list' do
      inputs = { subscription: subscription_resource.to_json }
      result = run(test, inputs)
      expect(result.result).to eq('pass')
    end

    it 'fails when the wrong headers are in the list' do
      subscription_resource['channel']['payload'] = 'application/json'
      subscription_resource.dig('channel', 'header') << 'accept: application/json'
      inputs = { subscription: subscription_resource.to_json }
      result = run(test, inputs)
      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to eq('Content type of request does not match the Subscription MIME type. ' \
                                                'Expected application/json, received application/fhir+json ' \
                                                "Requested header not sent: accept: application/json\n")
    end
  end

  describe 'Notification Header Verification Error Handling' do
    let(:subscription_resource) do
      JSON.parse(File.read(File.join(
                             __dir__, '../..', 'fixtures', 'subscription_resource_example.json'
                           )))
    end

    let(:test) do
      Class.new(Inferno::Test) do
        include SubscriptionsTestKit::NotificationConformanceVerification

        input :subscription

        run do
          notification_header_verification([], JSON.parse(subscription))
          no_error_verification('There were verification errors')
        end
      end
    end

    before do
      Inferno::Repositories::Tests.new.insert(test)
    end

    it 'fails when the content-type header and requesed header are blank' do
      subscription_resource['channel']['payload'] = 'application/fhir+json'
      subscription_resource.dig('channel', 'header') << 'accept: application/fhir+json'
      inputs = { subscription: subscription_resource.to_json }
      result = run(test, inputs)
      expect(result.result).to eq('fail')
      expect(entity_result_message(test)).to eq(
        "Content type header not sent, subscription requested application/fhir+json\n " \
        "Requested header not sent: Authorization: Bearer SAMPLE_TOKEN\n " \
        "Requested header not sent: accept: application/fhir+json\n"
      )
    end
  end
end
