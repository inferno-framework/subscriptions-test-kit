# frozen_string_literal: true

module SubscriptionsTestKit
  SUBSCRIPTION_CHANNEL_PATH = '/subscription/channel/notification_listener'
  FHIR_SUBSCRIPTION_PATH = '/fhir/Subscription'
  FHIR_SUBSCRIPTION_INSTANCE_PATH = '/fhir/Subscription/:id'
  FHIR_SUBSCRIPTION_INSTANCE_STATUS_PATH = '/fhir/Subscription/:id/$status'
  FHIR_SUBSCRIPTION_RESOURCE_STATUS_PATH = '/fhir/Subscription/$status'
  RESUME_PASS_PATH = '/resume_pass'
  RESUME_FAIL_PATH = '/resume_fail'

  module URLs
    def server_suite_base_url
      @server_suite_base_url ||= "#{Inferno::Application['base_url']}/custom/#{server_suite_id}"
    end

    def client_suite_base_url
      @client_suite_base_url ||= "#{Inferno::Application['base_url']}/custom/#{client_suite_id}"
    end

    def subscription_channel_url
      @subscription_channel_url ||= server_suite_base_url + SUBSCRIPTION_CHANNEL_PATH
    end

    def resume_pass_url_server
      @resume_pass_url_server ||= server_suite_base_url + RESUME_PASS_PATH
    end

    def resume_fail_url_server
      @resume_fail_url_server ||= server_suite_base_url + RESUME_FAIL_PATH
    end

    def fhir_subscription_url
      @fhir_subscription_url ||= client_suite_base_url + FHIR_SUBSCRIPTION_PATH
    end

    def resume_pass_url_client
      @resume_pass_url_client ||= client_suite_base_url + RESUME_PASS_PATH
    end

    def resume_fail_url_client
      @resume_fail_url_client ||= client_suite_base_url + RESUME_FAIL_PATH
    end

    def server_suite_id
      SubscriptionsR5BackportR4Server::SubscriptionsR5BackportR4ServerSuite.id
    end

    def client_suite_id
      SubscriptionsR5BackportR4Client::SubscriptionsR5BackportR4ClientSuite.id
    end
  end
end
