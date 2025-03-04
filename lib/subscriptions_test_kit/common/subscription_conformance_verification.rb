require_relative '../urls'

module SubscriptionsTestKit
  module SubscriptionConformanceVerification
    include URLs

    def no_error_verification(message)
      assert messages.none? { |msg| msg[:type] == 'error' }, message
    end

    def channel_field_matches?(subscription_channel, field_name, expected_entry)
      subscription_channel[field_name].present? && subscription_channel[field_name] == expected_entry
    end

    def cross_version_extension?(url)
      url.match?(%r{http://hl7\.org/fhir/[0-9]+\.[0-9]+/StructureDefinition/extension-Subscription\..+})
    end

    def check_extension(extensions)
      extensions.each do |extension|
        next unless cross_version_extension?(extension['url'])

        add_message('warning', %(
          Cross-version extensions SHOULD NOT be used on R4 subscriptions to describe any elements also described by
          this guide, but found the #{extension['url']} extension on the Subscription resource
        ))
      end
    end

    def cross_version_extension_check(subscription)
      subscription.each do |key, value|
        if value.is_a?(Array) && key == 'extension'
          check_extension(value)
        elsif value.is_a?(Hash) || value.is_a?(Array)
          cross_version_extension_check(value)
        end
      end
    end

    def valid_url?(url)
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) && !uri.host.nil?
    rescue URI::InvalidURIError
      false
    end

    def subscription_verification(subscription_resource)
      assert_valid_json(subscription_resource)
      subscription = JSON.parse(subscription_resource)

      subscription_channel = subscription['channel']
      assert(channel_field_matches?(subscription_channel, 'type', 'rest-hook'), %(
        The `type` element on the Subscription resource must be set to `rest-hook`,
        the `#{subscription_channel['type']}` channel type is unsupported.))

      unless subscription['criteria'].present? && valid_url?(subscription['criteria'])
        add_message('error',
                    %(
                      'The `criteria` element SHALL be populated and contain the canonical
                      URL for the Subscription Topic.'
                    ))
      end
      subscription_resource = FHIR.from_contents(subscription.to_json)
      assert_resource_type('Subscription', resource: subscription_resource)
      assert_valid_resource(resource: subscription_resource,
                            profile_url: 'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-subscription')

      cross_version_extension_check(subscription)
      subscription
    end

    def server_check_channel(subscription, access_token)
      subscription_channel = subscription['channel']
      unless channel_field_matches?(subscription_channel, 'endpoint', subscription_channel_url)
        add_message('warning', %(
                  The subscription url was changed from #{subscription_channel['endpoint']} to
                  #{subscription_channel_url}))
        subscription_channel['endpoint'] = subscription_channel_url
      end

      unless channel_field_matches?(subscription_channel, 'payload', 'application/fhir+json')
        update_message = if channel_field_matches?(subscription_channel, 'payload', 'application/json')
                           ''
                         else
                           subscription_channel['payload'] = 'application/fhir+json'
                           ' The requested Subscription has been updated to use this value.'
                         end

        add_message('warning', %(
          The `payload` element on the Subscription resource should be set to `application/fhir+json`, which is the
          [correct mime type for FHIR JSON](https://hl7.org/fhir/R4/http.html#mime-type).#{update_message}
        ))
      end

      unless subscription_channel['header'].present? &&
             subscription_channel['header'].include?("Authorization: Bearer #{access_token}")
        add_message('warning', %(
          Added the Authorization header field with a Bearer token set to #{access_token} to the `header` field on the
          Subscription resource in order to connect successfully with the Inferno subscription channel.
        ))
        subscription_channel['header'] = [] unless subscription_channel['header'].present?
        subscription_channel['header'].append("Authorization: Bearer #{access_token}")
      end
      subscription['channel'] = subscription_channel
      subscription
    end
  end
end
