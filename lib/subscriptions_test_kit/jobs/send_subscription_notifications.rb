# frozen_string_literal: true

require_relative '../tags'
require_relative '../suites/subscriptions_r5_backport_r4_client/common/subscription_simulation_utils'

module SubscriptionsTestKit
  module Jobs
    class SendSubscriptionNotifications
      include Sidekiq::Job
      include SubscriptionsR5BackportR4Client::SubscriptionSimulationUtils

      sidekiq_options retry: false

      def perform(test_run_id, test_session_id, result_id, subscription_id, subscription_url, client_endpoint,
                  bearer_token, notification_json, test_run_identifier, test_suite_base_url)
        @test_run_id = test_run_id
        @test_session_id = test_session_id
        @result_id = result_id
        @subscription_id = subscription_id
        @subscription_url = subscription_url
        @client_endpoint = client_endpoint
        @bearer_token = bearer_token
        @notification_json = notification_json
        @test_run_identifier = test_run_identifier
        @test_suite_base_url = test_suite_base_url

        await_subcription_creation
        sleep 1
        return unless test_still_waiting?

        send_handshake_notification
        sleep rand(5..10)
        return unless test_still_waiting?

        send_event_notification
      end

      def requests_repo
        @requests_repo ||= Inferno::Repositories::Requests.new
      end

      def results_repo
        @results_repo ||= Inferno::Repositories::Results.new
      end

      def subscription
        @subscription ||= find_subscription(@test_session_id)
      end

      def headers
        @headers ||= subscription_headers.merge(content_type_header).merge(authorization_header)
      end

      def rest_hook_connection
        @rest_hook_connection ||= Faraday.new(url: @client_endpoint, request: { open_timeout: 30 }, headers:)
      end

      def test_suite_connection
        @test_suite_connection ||= Faraday.new(@test_suite_base_url)
      end

      def content_type_header
        @content_type_header ||= { 'Content-Type' => actual_mime_type(subscription) }
      end

      def subscription_headers
        @subscription_headers ||= subscription&.channel&.header&.each_with_object({}) do |header, hash|
          header_name, header_value = header.split(': ', 2)
          hash[header_name] = header_value
        end || {}
      end

      def authorization_header
        @authorization_header ||= @bearer_token.present? ? { 'Authorization' => "Bearer #{@bearer_token}" } : {}
      end

      def subscription_topic
        @subscription_topic ||= subscription&.criteria
      end

      def test_still_waiting?
        results_repo.find_waiting_result(test_run_id: @test_run_id)
      end

      def await_subcription_creation
        sleep 0.5 until subscription.present?
      end

      def send_handshake_notification
        handshake_json = derive_handshake_notification(@notification_json, @subscription_url,
                                                       subscription_topic).to_json
        response = send_notification(handshake_json)
        persist_notification_request(response, [REST_HOOK_HANDSHAKE_NOTIFICATION_TAG])
        resume_inferno_test unless response.status == 200
      end

      def send_event_notification
        event_json = derive_event_notification(@notification_json, @subscription_url, subscription_topic, 1).to_json
        response = send_notification(event_json)
        persist_notification_request(response, [REST_HOOK_EVENT_NOTIFICATION_TAG])
      end

      def resume_inferno_test
        test_suite_connection.get(RESUME_PASS_PATH.delete_prefix('/'), { test_run_identifier: @test_run_identifier })
      end

      def send_notification(request_body)
        rest_hook_connection.post('', request_body)
      rescue Faraday::Error => e
        # Warning: This is a hack. If there is an error with the request such that we never get a response, we have
        #          no clean way to persist that information for the Inferno test to check later. The solution here
        #          is to persist the request anyway with a status of nil, using the error message as response body
        Faraday::Response.new(response_body: e.message, url: rest_hook_connection.url_prefix.to_s)
      end

      def persist_notification_request(response, tags)
        inferno_request_headers = headers.map { |name, value| { name:, value: } }
        inferno_response_headers = response.headers&.map { |name, value| { name:, value: } }
        requests_repo.create(
          verb: 'POST',
          url: response.env.url.to_s,
          direction: 'outgoing',
          status: response.status,
          request_body: response.env.request_body,
          response_body: response.env.response_body,
          test_session_id: @test_session_id,
          result_id: @result_id,
          request_headers: inferno_request_headers,
          response_headers: inferno_response_headers,
          tags:
        )
      end
    end
  end
end
