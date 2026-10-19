RSpec.describe SubscriptionsTestKit::SubscriptionStatusEndpoint, :request, :runnable do
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

  def returned_subscription_status
    FHIR.from_contents(last_response.body).entry.first.resource
  end

  def error_text
    FHIR.from_contents(last_response.body).issue.first.details.text
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

  describe 'type-level GET' do
    it 'returns the status of the current Subscription when no inputs are given' do
      get(type_status_url)

      expect(last_response.status).to eq(200)
      expect(returned_subscription_status).to be_a(FHIR::Parameters)
    end

    it 'returns the status when repeated id and status query parameters match' do
      get("#{type_status_url}?id=other&id=#{subscription_id}&status=requested")

      expect(last_response.status).to eq(200)
      expect(returned_subscription_status).to be_a(FHIR::Parameters)
    end

    it 'returns not-found when the id query parameter does not match' do
      get("#{type_status_url}?id=other")

      expect(last_response.status).to eq(404)
    end

    it 'returns not-found when the status query parameter does not match' do
      get("#{type_status_url}?status=active")

      expect(last_response.status).to eq(404)
    end
  end

  describe 'type-level POST' do
    it 'returns the status when valueId and valueCode inputs match' do
      post_parameters(type_status_url, { name: 'id', valueId: subscription_id },
                      { name: 'status', valueCode: 'requested' })

      expect(last_response.status).to eq(200)
      expect(returned_subscription_status).to be_a(FHIR::Parameters)
    end

    it 'returns the status when the body is empty' do
      post(type_status_url)

      expect(last_response.status).to eq(200)
    end

    it 'returns not-found when the valueId input does not match' do
      post_parameters(type_status_url, { name: 'id', valueId: 'other' })

      expect(last_response.status).to eq(404)
    end

    it 'returns not-found when the valueCode input does not match' do
      post_parameters(type_status_url, { name: 'status', valueCode: 'active' })

      expect(last_response.status).to eq(404)
    end

    it 'rejects inputs sent as valueString' do
      post_parameters(type_status_url, { name: 'id', valueString: subscription_id },
                      { name: 'status', valueString: 'requested' })

      expect(last_response.status).to eq(400)
      expect(FHIR.from_contents(last_response.body).issue.first.code).to eq('invalid')
      expect(error_text).to include('The `id` parameter must be sent as `valueId`.')
      expect(error_text).to include('The `status` parameter must be sent as `valueCode`.')
    end

    it 'names only the mistyped input' do
      post_parameters(type_status_url, { name: 'id', valueId: subscription_id },
                      { name: 'id', valueString: 'other' },
                      { name: 'status', valueCode: 'requested' })

      expect(last_response.status).to eq(400)
      expect(error_text).to eq('The `id` parameter must be sent as `valueId`.')
    end

    it 'rejects a body that is not a Parameters resource' do
      header 'Content-Type', 'application/fhir+json'
      post(type_status_url, FHIR::Bundle.new(type: 'collection').to_json)

      expect(last_response.status).to eq(400)
    end
  end

  describe 'instance-level' do
    it 'responds to GET' do
      get(instance_status_url)

      expect(last_response.status).to eq(200)
    end

    it 'responds to POST with an empty body' do
      post(instance_status_url)

      expect(last_response.status).to eq(200)
    end

    it 'uses the id from the url rather than an id query parameter' do
      get("/custom/#{suite_id}/fhir/Subscription/other/$status?id=#{subscription_id}")

      expect(last_response.status).to eq(404)
    end

    it 'returns not-found when the status query parameter does not match' do
      get("#{instance_status_url}?status=active")

      expect(last_response.status).to eq(404)
    end

    it 'returns not-found when the valueCode input does not match' do
      post_parameters(instance_status_url, { name: 'status', valueCode: 'active' })

      expect(last_response.status).to eq(404)
    end

    it 'rejects inputs sent as valueString' do
      post_parameters(instance_status_url, { name: 'status', valueString: 'requested' })

      expect(last_response.status).to eq(400)
      expect(error_text).to eq('The `status` parameter must be sent as `valueCode`.')
    end
  end
end
