RSpec.describe 'Simulated FHIR server error responses', :request do # rubocop:disable RSpec/DescribeClass
  let(:suite_id) { 'subscriptions_r5_backport_r4_client' }
  let(:base_path) { "/custom/#{suite_id}/fhir/Subscription" }

  before { header 'Authorization', 'Bearer NO_WAITING_SESSION' }

  [
    [:post, ''],
    [:get, '/123'],
    [:put, '/123'],
    [:patch, '/123'],
    [:delete, '/123'],
    [:get, '/123/$status'],
    [:post, '/123/$status'],
    [:post, '/$status']
  ].each do |verb, path|
    it "returns an OperationOutcome for #{verb.upcase} Subscription#{path} when no session is waiting" do
      send(verb, "#{base_path}#{path}", '{}')

      expect(last_response.status).to eq(500)
      expect(last_response.content_type).to start_with('application/fhir+json')
      outcome = FHIR.from_contents(last_response.body)
      expect(outcome).to be_a(FHIR::OperationOutcome)
      expect(outcome.issue.first.code).to eq('not-found')
      expect(outcome.issue.first.details.text).to include('NO_WAITING_SESSION')
    end
  end

  it 'returns a plain text error from the server suite notification endpoint' do
    post('/custom/subscriptions_r5_backport_r4_server/subscription/channel/notification_listener', '{}')

    expect(last_response.status).to eq(500)
    expect { JSON.parse(last_response.body) }.to raise_error(JSON::ParserError)
  end
end
