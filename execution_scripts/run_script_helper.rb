# frozen_string_literal: true

# Shared helpers for Subscriptions Test Kit execution scripts.
# These scripts drive the Inferno API programmatically to simulate a human
# tester running the test suite end-to-end against a reference server.

require 'net/http'
require 'json'
require 'uri'
require 'socket'

module RunScriptHelper
  POLL_INTERVAL      = 2   # seconds between status polls
  DEFAULT_TIMEOUT    = 120 # seconds before a wait times out
  NOTIFICATION_DELAY = 20  # seconds to allow the SendSubscriptionNotifications job to complete

  # Base URL of the running Inferno instance. Override with INFERNO_BASE_URL.
  def inferno_base_url
    ENV.fetch('INFERNO_BASE_URL', 'http://localhost:4567')
  end

  # ---------------------------------------------------------------------------
  # Inferno REST API helpers
  # ---------------------------------------------------------------------------

  def api_post(path, body)
    uri = URI("#{inferno_base_url}/api/#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    req = Net::HTTP::Post.new(uri.request_uri)
    req['Content-Type'] = 'application/json'
    req.body = body.to_json
    http.request(req)
  end

  def api_put(path, params = {})
    uri = URI("#{inferno_base_url}/api/#{path}")
    uri.query = URI.encode_www_form(params) unless params.empty?
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    req = Net::HTTP::Put.new(uri.request_uri)
    http.request(req)
  end

  def api_get(path)
    uri = URI("#{inferno_base_url}/api/#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.request(Net::HTTP::Get.new(uri.request_uri))
  end

  # Create a test session and apply a preset in one step.
  # Returns the parsed session object.
  def create_session(suite_id, preset_id)
    response = api_post('test_sessions', { test_suite_id: suite_id, preset_id: preset_id })
    unless response.code.start_with?('2')
      raise "Failed to create test session (HTTP #{response.code}): #{response.body}"
    end

    JSON.parse(response.body)
  end

  # Start a test run for the full suite.
  # Passes existing session data as inputs so required-input validation passes.
  # Returns the parsed test_run object.
  def start_test_run(session_id, suite_id)
    session_data = get_session_data(session_id)
    inputs = session_data.map { |name, value| { name: name, value: value } }

    response = api_post('test_runs', { test_session_id: session_id, test_suite_id: suite_id, inputs: inputs })
    unless response.code.start_with?('2')
      raise "Failed to start test run (HTTP #{response.code}): #{response.body}"
    end

    JSON.parse(response.body)
  end

  # Fetch current state of a test run.
  def get_test_run(test_run_id)
    response = api_get("test_runs/#{test_run_id}")
    JSON.parse(response.body)
  end

  # Fetch test run with all result details included.
  def get_test_run_with_results(test_run_id)
    uri = URI("#{inferno_base_url}/api/test_runs/#{test_run_id}?include_results=true")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    JSON.parse(response.body)
  end

  # Fetch all session data (inputs + outputs) as a flat name→value hash.
  def get_session_data(session_id)
    response = api_get("test_sessions/#{session_id}/session_data")
    JSON.parse(response.body).each_with_object({}) { |item, h| h[item['name']] = item['value'] }
  end

  # ---------------------------------------------------------------------------
  # Generic HTTP helpers (used to click wait-advancement URLs)
  # ---------------------------------------------------------------------------

  def http_get(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.request(Net::HTTP::Get.new(uri.request_uri))
  end

  # POST a FHIR resource to the given URL with a Bearer token.
  def http_post_fhir(url, body, access_token)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    req = Net::HTTP::Post.new(uri.request_uri)
    req['Content-Type'] = 'application/fhir+json'
    req['Authorization'] = "Bearer #{access_token}"
    req.body = body
    http.request(req)
  end

  # ---------------------------------------------------------------------------
  # Polling helpers
  # ---------------------------------------------------------------------------

  # Poll until the test run reaches "waiting" status.
  # Raises if the run completes without a wait state, or if the timeout expires.
  def wait_for_waiting_state(test_run_id, timeout: DEFAULT_TIMEOUT)
    puts "  Polling for wait state..."
    deadline = Time.now + timeout
    loop do
      test_run = get_test_run(test_run_id)
      status   = test_run['status']

      return test_run if status == 'waiting'
      raise "Test run finished before expected wait state (status: #{status})" if status == 'done'
      raise "Timeout (#{timeout}s) waiting for 'waiting' status. Last status: #{status}" if Time.now > deadline

      sleep POLL_INTERVAL
    end
  end

  # Poll until the test run reaches "done" status.
  def wait_for_completion(test_run_id, timeout: DEFAULT_TIMEOUT)
    puts "  Polling for completion..."
    deadline = Time.now + timeout
    loop do
      test_run = get_test_run(test_run_id)
      status   = test_run['status']

      return test_run if status == 'done'
      raise "Timeout (#{timeout}s) waiting for 'done' status. Last status: #{status}" if Time.now > deadline

      sleep POLL_INTERVAL
    end
  end

  # Retrieve a named output from session data, raising if it is absent.
  def fetch_output(session_id, name)
    data  = get_session_data(session_id)
    value = data[name]
    raise "Output '#{name}' not found in session data. Available: #{data.keys.join(', ')}" if value.nil?

    value
  end

  # ---------------------------------------------------------------------------
  # Notification listener (used by client suite scripts)
  # ---------------------------------------------------------------------------

  # Start a minimal HTTP server that responds 200 to everything.
  # Inferno's SendSubscriptionNotifications job POSTs handshake and event
  # notifications here.  The server must be reachable from the Inferno process
  # (requires Ruby developer mode, not Docker).
  #
  # Returns [server, thread, port].
  def start_notification_listener
    server = TCPServer.new(0)
    port = server.addr[1]
    thread = Thread.new do
      loop do
        client = server.accept
        client.recv(4096)
        client.write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        client.close
      end
    end
    puts "  Notification listener started on port #{port}"
    [server, thread, port]
  end

  def stop_notification_listener(server, thread)
    thread.kill
    server.close
    puts "  Notification listener stopped"
  end

  # ---------------------------------------------------------------------------
  # Subscription body builder (used by client suite scripts)
  # ---------------------------------------------------------------------------

  # The payload content extension URL defined by the Subscriptions Backport IG.
  PAYLOAD_CONTENT_EXT =
    'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-payload-content'

  # Build a conformant Subscription JSON body to POST to Inferno's FHIR endpoint
  # when the script acts as the FHIR client under test.
  #
  # @param notification_endpoint [String] URL where Inferno will deliver notifications
  # @param payload_code [String] "empty", "id-only", or "full-resource"
  # @return [String] JSON
  def build_subscription(notification_endpoint, payload_code)
    {
      'resourceType' => 'Subscription',
      'meta' => {
        'profile' => ['http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-subscription']
      },
      'status'  => 'requested',
      'end'     => '2025-12-31T12:00:00Z',
      'reason'  => 'R4 Topic-Based Workflow Subscription for Patient Admission',
      'criteria' =>
        'https://inferno.healthit.gov/suites/custom/subscriptions_r5_backport_r4_client/topics/patient-admission',
      '_criteria' => {
        'extension' => [{
          'url'         => 'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-filter-criteria',
          'valueString' => 'Encounter.patient=Patient/123'
        }]
      },
      'channel' => {
        'extension' => [
          {
            'url'              => 'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-timeout',
            'valueUnsignedInt' => 60
          },
          {
            'url'                => 'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-max-count',
            'valuePositiveInt'   => 20
          }
        ],
        'type'     => 'rest-hook',
        'header'   => ['Authorization: Bearer SAMPLE_TOKEN'],
        'endpoint' => notification_endpoint,
        'payload'  => 'application/fhir+json',
        '_payload' => {
          'extension' => [{
            'url'       => PAYLOAD_CONTENT_EXT,
            'valueCode' => payload_code
          }]
        }
      }
    }.to_json
  end

  # ---------------------------------------------------------------------------
  # Result reporting
  # ---------------------------------------------------------------------------

  # Print a result summary and raise if any test failed or errored.
  def assert_all_tests_passed(test_run_id, session_id, suite_id)
    test_run = get_test_run_with_results(test_run_id)
    results  = test_run['results'] || []

    by_status = results.group_by { |r| r['result'] }
    failures  = (by_status['fail'] || []) + (by_status['error'] || [])

    puts "\nResults:"
    %w[pass skip omit fail error].each do |s|
      count = (by_status[s] || []).length
      puts "  #{s.ljust(5)}: #{count}" if count.positive?
    end
    puts "\nSession URL: #{inferno_base_url}/#{suite_id}/#{session_id}"

    return puts("\nAll required tests passed!") if failures.empty?

    puts "\nFailed / Errored tests:"
    failures.each { |r| puts "  [#{r['result']}] #{r['test_id']}" }
    raise "Test run completed with #{failures.length} failure(s)/error(s)"
  end
end
