#!/usr/bin/env ruby
# frozen_string_literal: true

# Execution script: Subscriptions R4 Server Suite — Empty payload type
#
# Tests the Inferno Subscriptions R4 Server suite using the "Empty Notifications
# Against The Subscriptions Client Suite" preset.  Inferno acts as the client,
# POSTing the Subscription to the client suite's FHIR endpoint.  The client
# suite's SendSubscriptionNotifications job automatically delivers handshake and
# event notifications back to the server suite's listener.
#
# Usage:
#   bundle exec ruby execution_scripts/subscriptions_r4_server_empty.rb
#
# Environment:
#   INFERNO_BASE_URL  Base URL of the running Inferno instance
#                     (default: http://localhost:4567)

require_relative 'run_script_helper'
include RunScriptHelper

SUITE_ID  = 'subscriptions_r5_backport_r4_server'
PRESET_ID = 'inferno-subscriptions_r5_backport_r4_server_preset_empty'

puts '=== Subscriptions R4 Server Suite — Empty Payload ==='
puts "Base URL: #{inferno_base_url}"

# 1. Create session and apply preset
puts "\n[1/5] Creating test session with preset..."
session    = create_session(SUITE_ID, PRESET_ID)
session_id = session['id']
puts "  Session ID:  #{session_id}"
puts "  Session URL: #{inferno_base_url}/#{SUITE_ID}/#{session_id}"

# 2. Start the full suite test run
puts "\n[2/5] Starting test run..."
test_run    = start_test_run(session_id, SUITE_ID)
test_run_id = test_run['id']
puts "  Test Run ID: #{test_run_id}"

# 3. The workflow group's NotificationDeliveryTest POSTs the Subscription to the
# client suite's FHIR endpoint and then waits.  The client suite's
# SubscriptionCreateEndpoint queues SendSubscriptionNotifications, which will
# deliver handshake and event notifications to the server suite's listener.
puts "\n[3/5] Waiting for notification delivery wait state..."
wait_for_waiting_state(test_run_id)

puts "  Sleeping #{NOTIFICATION_DELAY}s for background notifications to be delivered..."
sleep NOTIFICATION_DELAY

# 4. Resume the wait by visiting the confirmation URL that the test outputted.
puts "\n[4/5] Advancing wait state via confirmation URL..."
confirmation_url = fetch_output(session_id, 'confirmation_url')
puts "  GET #{confirmation_url}"
http_get(confirmation_url)

# 5. All remaining groups (capability statement, handshake/heartbeat, status
# operation, subscription rejection) run automatically with no further waits.
puts "\n[5/5] Waiting for test run to complete..."
wait_for_completion(test_run_id)

assert_all_tests_passed(test_run_id, session_id, SUITE_ID)
