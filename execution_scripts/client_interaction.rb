#!/usr/bin/env ruby
# frozen_string_literal: true

# Command script used by client suite YAML execution scripts.
# Invoked when the InteractionTest is in the waiting state.
#
# 1. Starts a local HTTP listener so Inferno can deliver handshake and event
#    notifications to a real endpoint.
# 2. POSTs a conformant Subscription to Inferno's FHIR endpoint.
# 3. Sleeps to allow the SendSubscriptionNotifications job to complete.
# 4. Advances the InteractionTest wait via the confirmation URL.
#
# Args:
#   ARGV[0] - confirmation_url  (from {wait_outputs.confirmation_url})
#   ARGV[1] - payload_code      ("empty", "id-only", or "full-resource")
#
# Environment:
#   INFERNO_BASE_URL  Base URL of the running Inferno instance
#                     (default: http://localhost:4567)

require 'net/http'
require 'json'
require 'uri'
require 'socket'

SUITE_ID            = 'subscriptions_r5_backport_r4_client'
ACCESS_TOKEN        = 'SAMPLE_TOKEN'
NOTIFICATION_DELAY  = 20
PAYLOAD_CONTENT_EXT = 'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-payload-content'

confirmation_url = ARGV[0]
payload_code     = ARGV[1]
inferno_base_url = ENV.fetch('INFERNO_BASE_URL', 'http://localhost:4567')

raise "Usage: #{$0} <confirmation_url> <payload_code>" if confirmation_url.nil? || payload_code.nil?

# ---------------------------------------------------------------------------
# Start notification listener
# ---------------------------------------------------------------------------

listener = TCPServer.new(0)
port     = listener.addr[1]
thread   = Thread.new do
  loop do
    client = listener.accept
    client.recv(4096)
    client.write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
    client.close
  end
end
puts "Notification listener started on port #{port}"

# ---------------------------------------------------------------------------
# POST Subscription to Inferno
# ---------------------------------------------------------------------------

subscription_body = {
  'resourceType' => 'Subscription',
  'meta' => {
    'profile' => ['http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-subscription']
  },
  'status'   => 'requested',
  'end'      => '2025-12-31T12:00:00Z',
  'reason'   => 'R4 Topic-Based Workflow Subscription for Patient Admission',
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
        'url'              => 'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-max-count',
        'valuePositiveInt' => 20
      }
    ],
    'type'     => 'rest-hook',
    'header'   => ["Authorization: Bearer #{ACCESS_TOKEN}"],
    'endpoint' => "http://localhost:#{port}",
    'payload'  => 'application/fhir+json',
    '_payload' => {
      'extension' => [{
        'url'       => PAYLOAD_CONTENT_EXT,
        'valueCode' => payload_code
      }]
    }
  }
}.to_json

uri = URI("#{inferno_base_url}/custom/#{SUITE_ID}/fhir/Subscription")
http = Net::HTTP.new(uri.host, uri.port)
req  = Net::HTTP::Post.new(uri.request_uri)
req['Content-Type']  = 'application/fhir+json'
req['Authorization'] = "Bearer #{ACCESS_TOKEN}"
req.body = subscription_body

response = http.request(req)
puts "Subscription POST → HTTP #{response.code}"
raise "Subscription POST failed (HTTP #{response.code}): #{response.body}" unless response.code == '201'

# ---------------------------------------------------------------------------
# Wait for notifications then advance the InteractionTest wait state
# ---------------------------------------------------------------------------

puts "Sleeping #{NOTIFICATION_DELAY}s for Inferno to deliver handshake and event notification..."
sleep NOTIFICATION_DELAY

puts "Advancing InteractionTest wait: #{confirmation_url}"
uri = URI(confirmation_url)
Net::HTTP.new(uri.host, uri.port).request(Net::HTTP::Get.new(uri.request_uri))

thread.kill
listener.close
puts "Interaction step complete."
