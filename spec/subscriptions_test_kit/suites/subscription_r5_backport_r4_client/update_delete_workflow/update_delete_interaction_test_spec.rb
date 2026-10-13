RSpec.describe SubscriptionsTestKit::SubscriptionsR5BackportR4Client::UpdateDeleteInteractionTest, :request do
  let(:suite_id) { 'subscriptions_r5_backport_r4_client' }
  let(:test) { find_test suite, described_class.id }
  let(:results_repo) { Inferno::Repositories::Results.new }
  let(:access_token) { '1234' }
  let(:subscription_id) { 'abc-123' }
  let(:subscription_url) { "/custom/#{suite_id}/fhir/Subscription/#{subscription_id}" }
  let(:resume_pass_url) { "/custom/#{suite_id}/resume_pass" }
  let(:subscription) do
    subscription = JSON.parse(File.read(File.join(__dir__, '../../../..', 'fixtures',
                                                  'subscription_resource_example.json')))
    # Inferno does not support heartbeats
    subscription['channel']['extension'].reject! { |e| e['url'].end_with?('backport-heartbeat-period') }
    subscription.merge('id' => subscription_id)
  end
  let(:notification_json) do
    File.read(File.join(__dir__, '../../../..', 'fixtures', 'empty_notification_bundle_example.json'))
  end

  def create_subscription_request
    repo_create(
      :request,
      verb: 'POST',
      url: "http://example.com/custom/#{suite_id}/fhir/Subscription",
      direction: 'incoming',
      status: 201,
      request_body: subscription.except('id').to_json,
      response_body: subscription.to_json,
      result: repo_create(:result, test_session_id: test_session.id),
      test_session_id: test_session.id,
      tags: [SubscriptionsTestKit::SUBSCRIPTION_CREATE_TAG]
    )
  end

  def authorize
    header 'Authorization', "Bearer #{access_token}"
  end

  def json_patch(path, operations, content_type: 'application/json-patch+json')
    header 'Content-Type', content_type
    patch(path, operations.to_json)
  end

  it 'skips when no Subscription was created' do
    result = run(test, access_token:)
    expect(result.result).to eq('skip')
  end

  describe 'when a Subscription was created' do
    before { create_subscription_request }

    it 'waits and outputs the url of the Subscription' do
      result = run(test, access_token:)
      expect(result.result).to eq('wait')
      expect(JSON.parse(result.output_json).find { |o| o['name'] == 'subscription_url' }['value'])
        .to end_with(subscription_url)
    end

    it 'responds to updates and deletes of the Subscription' do
      result = run(test, access_token:)
      expect(result.result).to eq('wait')

      updated_subscription = subscription.merge('reason' => 'updated reason', 'status' => 'off')
      authorize
      put(subscription_url, updated_subscription.to_json)
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to include('reason' => 'updated reason', 'status' => 'off')

      get(subscription_url)
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to include('reason' => 'updated reason', 'status' => 'off')

      delete(subscription_url)
      expect(last_response.status).to eq(204)

      get(subscription_url)
      expect(last_response.status).to eq(404)

      put(subscription_url, updated_subscription.to_json)
      expect(last_response.status).to eq(404)

      get("#{resume_pass_url}?test_run_identifier=#{access_token}")
      expect(results_repo.find(result.id).result).to eq('pass')
    end

    it 'starts from the created Subscription when an earlier run deleted it' do
      run(test, access_token:)
      authorize
      delete(subscription_url)
      expect(last_response.status).to eq(204)
      get("#{resume_pass_url}?test_run_identifier=#{access_token}")

      expect(run(test, access_token:).result).to eq('wait')
      get(subscription_url)
      expect(last_response.status).to eq(200)
    end

    it 'starts from the created Subscription when an earlier run updated it' do
      run(test, access_token:)
      authorize
      put(subscription_url, subscription.merge('reason' => 'updated reason').to_json)
      get("#{resume_pass_url}?test_run_identifier=#{access_token}")

      expect(run(test, access_token:).result).to eq('wait')
      get(subscription_url)
      expect(JSON.parse(last_response.body)['reason']).to eq(subscription['reason'])
    end

    describe 'while a different test is waiting' do
      let(:workflow_test) { find_test suite, SubscriptionsTestKit::SubscriptionsR5BackportR4Client::InteractionTest.id }

      before do
        run(workflow_test, access_token:, notification_bundle: notification_json)
        authorize
      end

      it 'rejects updates and deletes of the Subscription' do
        put(subscription_url, subscription.merge('reason' => 'updated reason').to_json)
        expect(last_response.status).to eq(422)

        header 'Content-Type', 'application/json-patch+json'
        patch(subscription_url, [{ op: 'replace', path: '/reason', value: 'patched reason' }].to_json)
        expect(last_response.status).to eq(422)

        delete(subscription_url)
        expect(last_response.status).to eq(422)

        get(subscription_url)
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)['reason']).to eq(subscription['reason'])
      end

      it 'does not apply rejected changes during a later run of the update and delete tests' do
        delete(subscription_url)
        get("#{resume_pass_url}?test_run_identifier=#{access_token}")

        run(test, access_token:)
        get(subscription_url)
        expect(last_response.status).to eq(200)
      end
    end

    it 'responds to $status requests while waiting' do
      session_data_repo.save(test_session_id: test_session.id, name: 'notification_bundle',
                             value: notification_json, type: 'textarea')
      run(test, access_token:)

      authorize
      get("#{subscription_url}/$status")
      expect(last_response.status).to eq(200)
      expect(FHIR.from_contents(last_response.body)).to be_a(FHIR::Bundle)
    end

    it 'reports a client-requested off status from $status' do
      session_data_repo.save(test_session_id: test_session.id, name: 'notification_bundle',
                             value: notification_json, type: 'textarea')
      run(test, access_token:)

      authorize
      put(subscription_url, subscription.merge('status' => 'off').to_json)

      get("#{subscription_url}/$status")
      expect(last_response.status).to eq(200)
      status_param = FHIR.from_contents(last_response.body).entry.first.resource
        .parameter.find { |p| p.name == 'status' }
      expect(status_param.valueCode).to eq('off')
    end

    it 'rejects a $status request for a Subscription that does not exist' do
      session_data_repo.save(test_session_id: test_session.id, name: 'notification_bundle',
                             value: notification_json, type: 'textarea')
      run(test, access_token:)

      authorize
      get("/custom/#{suite_id}/fhir/Subscription/other/$status")
      expect(last_response.status).to eq(404)
    end

    it 'rejects an update when the id in the body does not match the url' do
      run(test, access_token:)

      authorize
      put(subscription_url, subscription.merge('id' => 'other').to_json)
      expect(last_response.status).to eq(400)
    end

    it 'rejects an update whose body is not a JSON object' do
      run(test, access_token:)

      authorize
      put(subscription_url, 'null')
      expect(last_response.status).to eq(400)

      get(subscription_url)
      expect(last_response.status).to eq(200)
    end

    it 'rejects an update of a Subscription that does not exist' do
      run(test, access_token:)

      authorize
      put("/custom/#{suite_id}/fhir/Subscription/other", subscription.merge('id' => 'other').to_json)
      expect(last_response.status).to eq(404)
    end

    describe 'with a JSON Patch request' do
      before do
        run(test, access_token:)
        authorize
      end

      it 'applies the patch to the Subscription' do
        json_patch(subscription_url, [{ op: 'test', path: '/status', value: 'requested' },
                                      { op: 'replace', path: '/reason', value: 'patched reason' }])
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to include('id' => subscription_id, 'reason' => 'patched reason')
        expect(JSON.parse(last_response.body).dig('channel', '_payload')).to be_present

        get(subscription_url)
        expect(JSON.parse(last_response.body)).to include('reason' => 'patched reason')
      end

      it 'applies the patch to the latest version of the Subscription' do
        put(subscription_url, subscription.merge('reason' => 'updated reason').to_json)
        json_patch(subscription_url, [{ op: 'test', path: '/reason', value: 'updated reason' },
                                      { op: 'replace', path: '/status', value: 'off' }])
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to include('reason' => 'updated reason', 'status' => 'off')
      end

      it 'rejects patch formats other than JSON Patch' do
        json_patch(subscription_url, { resourceType: 'Parameters' }, content_type: 'application/fhir+json')
        expect(last_response.status).to eq(415)
      end

      it 'rejects a body that is not a JSON Patch document' do
        json_patch(subscription_url, { op: 'remove', path: '/reason' })
        expect(last_response.status).to eq(400)
      end

      {
        'an unknown op' => { op: 'frob', path: '/reason' },
        'a missing path' => { op: 'remove' },
        'a path that is not a string' => { op: 'replace', path: 5, value: 'patched reason' },
        'a missing value' => { op: 'replace', path: '/reason' },
        'a missing from' => { op: 'copy', path: '/reason' },
        'a from that is not a string' => { op: 'move', from: 5, path: '/reason' }
      }.each do |description, operation|
        it "rejects a JSON Patch operation with #{description}" do
          json_patch(subscription_url, [operation])
          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body).dig('issue', 0, 'details', 'text'))
            .to eq('Request body is not a valid JSON Patch document')
        end
      end

      it 'accepts a JSON Patch operation with a null value' do
        json_patch(subscription_url, [{ op: 'add', path: '/error', value: nil }])
        expect(last_response.status).to eq(200)
      end

      it 'rejects a patch that cannot be applied' do
        json_patch(subscription_url, [{ op: 'test', path: '/reason', value: 'something else' }])
        expect(last_response.status).to eq(422)
      end

      {
        'copies from an array index that does not exist' => [
          { op: 'copy', from: '/channel/header/99', path: '/reason' }
        ],
        'has a path through a number' => [
          { op: 'add', path: '/count', value: 1 }, { op: 'add', path: '/count/a/b', value: 1 }
        ],
        'has a path through a boolean' => [
          { op: 'add', path: '/flag', value: true }, { op: 'test', path: '/flag/a/b', value: 1 }
        ]
      }.each do |description, operations|
        it "rejects a patch that #{description}" do
          json_patch(subscription_url, operations)
          expect(last_response.status).to eq(422)
          expect(JSON.parse(last_response.body).dig('issue', 0, 'details', 'text'))
            .to start_with('Unable to apply JSON Patch')
        end
      end

      it 'accepts a JSON Patch Content-Type in any case' do
        json_patch(subscription_url, [{ op: 'replace', path: '/reason', value: 'patched reason' }],
                   content_type: 'Application/JSON-Patch+json')
        expect(last_response.status).to eq(200)
      end

      [nil, 'not a subscription', []].each do |value|
        it "rejects a patch that replaces the Subscription with #{value.inspect}" do
          json_patch(subscription_url, [{ op: 'replace', path: '', value: }])
          expect(last_response.status).to eq(422)

          get(subscription_url)
          expect(last_response.status).to eq(200)
        end
      end

      it 'rejects a patch that results in a Subscription Inferno does not support' do
        json_patch(subscription_url, [{ op: 'replace', path: '/channel/type', value: 'websocket' }])
        expect(last_response.status).to eq(400)
      end

      it 'rejects a patch that changes the Subscription id' do
        json_patch(subscription_url, [{ op: 'replace', path: '/id', value: 'other' }])
        expect(last_response.status).to eq(400)
      end
    end

    it 'rejects a delete of a Subscription that does not exist' do
      run(test, access_token:)

      authorize
      delete("/custom/#{suite_id}/fhir/Subscription/other")
      expect(last_response.status).to eq(404)
    end
  end
end
