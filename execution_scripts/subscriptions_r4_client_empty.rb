#!/usr/bin/env ruby
# frozen_string_literal: true

# Execution script: Subscriptions R4 Client Suite — Empty payload type
#
# Tests the Inferno Subscriptions R4 Client suite using the "Inferno Subscription
# R4 Client Empty Preset".  This script plays the role of the FHIR client under
# test, performing the two manual steps that a human tester would ordinarily do:
#
#   1. POST a Subscription to Inferno's simulated FHIR server so that Inferno
#      sends back a handshake and an event notification.
#   2. Attest (via the attestation URL) that the event notification was processed
#      correctly.
#
# A minimal WEBrick HTTP listener is started locally to receive the handshake
# and event notifications that Inferno's background job delivers.  This requires
# Inferno to be running in Ruby developer mode (not Docker) so that it can reach
# localhost on the listener port.
#
# Usage:
#   bundle exec ruby execution_scripts/subscriptions_r4_client_empty.rb
#
# Environment:
#   INFERNO_BASE_URL  Base URL of the running Inferno instance
#                     (default: http://localhost:4567)

require_relative 'run_script_helper'
include RunScriptHelper

SUITE_ID     = 'subscriptions_r5_backport_r4_client'
PRESET_ID    = 'inferno-subscriptions_r5_backport_r4_client_empty'
ACCESS_TOKEN = 'SAMPLE_TOKEN'
PAYLOAD_CODE = 'empty'

puts '=== Subscriptions R4 Client Suite — Empty Payload ==='
puts "Base URL: #{inferno_base_url}"

# 1. Start the notification listener so Inferno can deliver handshake and event
#    notifications to a real HTTP endpoint that responds 200.
puts "\n[1/7] Starting notification listener..."
listener_server, listener_thread, listener_port = start_notification_listener
notification_endpoint = "http://localhost:#{listener_port}"

# 2. Create session and apply the client preset.
puts "\n[2/7] Creating test session with preset..."
session    = create_session(SUITE_ID, PRESET_ID)
session_id = session['id']
puts "  Session ID:  #{session_id}"
puts "  Session URL: #{inferno_base_url}/#{SUITE_ID}/#{session_id}"

# 3. Start the full suite test run.
puts "\n[3/7] Starting test run..."
test_run    = start_test_run(session_id, SUITE_ID)
test_run_id = test_run['id']
puts "  Test Run ID: #{test_run_id}"

# 4. The InteractionTest waits for a Subscription POST to arrive at Inferno's
#    FHIR endpoint.  Once received, Inferno's background job sends a handshake
#    followed by an event notification to the subscription's channel.endpoint.
puts "\n[4/7] Waiting for subscription interaction wait state..."
wait_for_waiting_state(test_run_id)

puts "  POSTing Subscription to Inferno as the FHIR client under test..."
fhir_subscription_url = "#{inferno_base_url}/custom/#{SUITE_ID}/fhir/Subscription"
subscription_body     = build_subscription(notification_endpoint, PAYLOAD_CODE)
response = http_post_fhir(fhir_subscription_url, subscription_body, ACCESS_TOKEN)
puts "  Subscription POST → HTTP #{response.code}"
raise "Subscription POST failed (HTTP #{response.code}): #{response.body}" unless response.code == '201'

puts "  Sleeping #{NOTIFICATION_DELAY}s for Inferno to send handshake and event notification..."
sleep NOTIFICATION_DELAY

# 5. Resume the InteractionTest wait.  The test run will then execute the
#    handshake and event notification verification tests before hitting the
#    attestation wait.
puts "\n[5/7] Advancing subscription interaction wait state..."
confirmation_url = fetch_output(session_id, 'confirmation_url')
puts "  GET #{confirmation_url}"
http_get(confirmation_url)

# Give the server a moment to resume the run before we poll again.
sleep 3

# 6. ProcessingAttestationTest waits for the tester to confirm the event
#    notification was processed correctly.  The script attests "true".
puts "\n[6/7] Waiting for attestation wait state..."
wait_for_waiting_state(test_run_id)

puts "  Attesting that the event notification was processed correctly..."
attest_true_url = fetch_output(session_id, 'attest_true_url')
puts "  GET #{attest_true_url}"
http_get(attest_true_url)

# 7. All remaining tests run automatically.
puts "\n[7/7] Waiting for test run to complete..."
wait_for_completion(test_run_id)

assert_all_tests_passed(test_run_id, session_id, SUITE_ID)
stop_notification_listener(listener_server, listener_thread)
