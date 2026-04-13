#!/usr/bin/env ruby
# frozen_string_literal: true

# Execution script: Subscriptions R4 Server Suite — Full-Resource payload type
#
# Tests the Inferno Subscriptions R4 Server suite using the "Full Resource
# Notifications Against The Subscriptions Client Suite" preset.  Inferno acts as
# the client, POSTing the Subscription to the client suite's FHIR endpoint.  The
# client suite's SendSubscriptionNotifications job automatically delivers
# handshake and event notifications back to the server suite's listener.
#
# Usage:
#   bundle exec ruby execution_scripts/subscriptions_r4_server_full_resource.rb
#
# Environment:
#   INFERNO_BASE_URL  Base URL of the running Inferno instance
#                     (default: http://localhost:4567)

require_relative 'run_script_helper'
include RunScriptHelper

SUITE_ID  = 'subscriptions_r5_backport_r4_server'
PRESET_ID = 'inferno-subscriptions_r5_backport_r4_server_preset_full_resource'

puts '=== Subscriptions R4 Server Suite — Full-Resource Payload ==='
puts "Base URL: #{inferno_base_url}"

puts "\n[1/5] Creating test session with preset..."
session    = create_session(SUITE_ID, PRESET_ID)
session_id = session['id']
puts "  Session ID:  #{session_id}"
puts "  Session URL: #{inferno_base_url}/#{SUITE_ID}/#{session_id}"

puts "\n[2/5] Starting test run..."
test_run    = start_test_run(session_id, SUITE_ID)
test_run_id = test_run['id']
puts "  Test Run ID: #{test_run_id}"

puts "\n[3/5] Waiting for notification delivery wait state..."
wait_for_waiting_state(test_run_id)

puts "  Sleeping #{NOTIFICATION_DELAY}s for background notifications to be delivered..."
sleep NOTIFICATION_DELAY

puts "\n[4/5] Advancing wait state via confirmation URL..."
confirmation_url = fetch_output(session_id, 'confirmation_url')
puts "  GET #{confirmation_url}"
http_get(confirmation_url)

puts "\n[5/5] Waiting for test run to complete..."
wait_for_completion(test_run_id)

assert_all_tests_passed(test_run_id, session_id, SUITE_ID)
