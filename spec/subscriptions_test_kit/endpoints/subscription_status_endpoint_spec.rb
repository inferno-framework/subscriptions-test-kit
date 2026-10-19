RSpec.describe 'Subscription $status endpoints', :request, :runnable do # rubocop:disable RSpec/DescribeClass
  let(:suite_id) { 'subscriptions_r5_backport_r4_client' }
  let(:test) do
    find_test suite, SubscriptionsTestKit::SubscriptionsR5BackportR4Client::UpdateDeleteInteractionTest.id
  end
  let(:access_token) { '1234' }
  let(:subscription_id) { 'abc-123' }
  let(:type_status_url) { "/custom/#{suite_id}/fhir/Subscription/$status" }
  let(:instance_status_url) { "/custom/#{suite_id}/fhir/Subscription/#{subscription_id}/$status" }
  let(:subscription) do
    subscription = JSON.parse(File.read(File.join(__dir__, '../..', 'fixtures', 'subscription_resource_example.json')))
    subscription['channel']['extension'].reject! { |e| e['url'].end_with?('backport-heartbeat-period') }
    subscription.merge('id' => subscription_id)
  end
  let(:notification_json) do
    File.read(File.join(__dir__, '../..', 'fixtures', 'empty_notification_bundle_example.json'))
  end

  def post_parameters(url, *parameters)
    header 'Content-Type', 'application/fhir+json'
    post(url, FHIR::Parameters.new(parameter: parameters.map { |p| FHIR::Parameters::Parameter.new(p) }).to_json)
  end

  def response_resource
    FHIR.from_contents(last_response.body)
  end

  def expect_current_subscription_status
    expect(last_response.status).to eq(200)
    bundle = response_resource
    expect(bundle.type).to eq('searchset')
    parameters = bundle.entry.first.resource.parameter
    expect(parameters.find { |p| p.name == 'status' }.valueCode).to eq('requested')
    expect(parameters.find { |p| p.name == 'subscription' }.valueReference.reference)
      .to end_with("Subscription/#{subscription_id}")
  end

  def expect_error(status, code, text = nil)
    expect(last_response.status).to eq(status)
    issue = response_resource.issue.first
    expect(issue.code).to eq(code)
    expect(issue.details.text).to eq(text) if text
  end

  before do
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
    session_data_repo.save(test_session_id: test_session.id, name: 'notification_bundle',
                           value: notification_json, type: 'textarea')
    run(test, access_token:)
    header 'Authorization', "Bearer #{access_token}"
  end

  describe SubscriptionsTestKit::SubscriptionTypeStatusEndpoint do
    describe 'GET' do
      it 'returns the status of the current Subscription when no inputs are given' do
        get(type_status_url)

        expect_current_subscription_status
      end

      it 'returns the status when repeated id and status query parameters include a match' do
        get("#{type_status_url}?id=other&id=#{subscription_id}&status=active&status=requested")

        expect_current_subscription_status
      end

      it 'returns not-found when the id query parameter does not match' do
        get("#{type_status_url}?id=other")

        expect_error(404, 'not-found')
      end

      it 'returns not-found when the status query parameter does not match' do
        get("#{type_status_url}?status=active")

        expect_error(404, 'not-found')
      end
    end

    describe 'POST' do
      it 'returns the status when valueId and valueCode inputs match' do
        post_parameters(type_status_url, { name: 'id', valueId: subscription_id },
                        { name: 'status', valueCode: 'requested' })

        expect_current_subscription_status
      end

      it 'returns the status when the body is empty' do
        post(type_status_url)

        expect_current_subscription_status
      end

      it 'returns not-found when the valueId input does not match' do
        post_parameters(type_status_url, { name: 'id', valueId: 'other' })

        expect_error(404, 'not-found')
      end

      it 'returns not-found when the valueCode input does not match' do
        post_parameters(type_status_url, { name: 'status', valueCode: 'active' })

        expect_error(404, 'not-found')
      end

      it 'rejects inputs sent as valueString' do
        post_parameters(type_status_url, { name: 'id', valueString: subscription_id },
                        { name: 'status', valueString: 'requested' })

        expect_error(400, 'invalid', 'The `id` parameter must have a non-empty `valueId`. ' \
                                     'The `status` parameter must have a non-empty `valueCode`.')
      end

      it 'names only the mistyped input' do
        post_parameters(type_status_url, { name: 'id', valueId: subscription_id },
                        { name: 'id', valueString: 'other' },
                        { name: 'status', valueCode: 'requested' })

        expect_error(400, 'invalid', 'The `id` parameter must have a non-empty `valueId`.')
      end

      it 'rejects an empty valueId' do
        header 'Content-Type', 'application/fhir+json'
        post(type_status_url, { resourceType: 'Parameters', parameter: [{ name: 'id', valueId: '' }] }.to_json)

        expect_error(400, 'invalid', 'The `id` parameter must have a non-empty `valueId`.')
      end

      it 'rejects a body that is not a Parameters resource' do
        header 'Content-Type', 'application/fhir+json'
        post(type_status_url, FHIR::Bundle.new(type: 'collection').to_json)

        expect_error(400, 'invalid', 'Invalid Parameters in request body')
      end
    end
  end

  describe SubscriptionsTestKit::SubscriptionStatusEndpoint do
    it 'responds to GET' do
      get(instance_status_url)

      expect_current_subscription_status
    end

    it 'responds to POST with an empty body' do
      post(instance_status_url)

      expect_current_subscription_status
    end

    it 'returns not-found for a different Subscription id in the url' do
      get("/custom/#{suite_id}/fhir/Subscription/other/$status?id=#{subscription_id}")

      expect_error(404, 'not-found')
    end

    it 'ignores id and status query parameters' do
      get("#{instance_status_url}?id=other&status=off")

      expect_current_subscription_status
    end

    it 'ignores id and status inputs in the body, whatever their type' do
      post_parameters(instance_status_url, { name: 'id', valueId: 'other' },
                      { name: 'status', valueString: 'off' })

      expect_current_subscription_status
    end

    it 'ignores a body that is not a Parameters resource' do
      header 'Content-Type', 'application/fhir+json'
      post(instance_status_url, FHIR::Bundle.new(type: 'collection').to_json)

      expect_current_subscription_status
    end
  end
end
