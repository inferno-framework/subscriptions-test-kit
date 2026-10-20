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

    def subscription_verification(subscription_resource, validator: :default)
      assert_valid_json(subscription_resource)
      subscription = JSON.parse(subscription_resource)
      assert(subscription.is_a?(Hash), 'The Subscription must be a JSON object.')

      subscription_channel = subscription['channel']
      assert(subscription_channel.is_a?(Hash), 'The Subscription must include a `channel` element.')
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
      assert_valid_resource(resource: subscription_resource, validator:,
                            profile_url: 'http://hl7.org/fhir/uv/subscriptions-backport/StructureDefinition/backport-subscription')

      cross_version_extension_check(subscription)
    end

    def server_check_channel(subscription, access_token)
      subscription_channel = subscription['channel']
      return subscription unless subscription_channel.is_a?(Hash)

      unless channel_field_matches?(subscription_channel, 'endpoint', subscription_channel_url)
        add_message('warning', <<~MESSAGE)
          The subscription url was changed from #{subscription_channel['endpoint']} to
          #{subscription_channel_url}
        MESSAGE
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

      server_check_channel_authorization_header(subscription_channel, access_token)
      subscription['channel'] = subscription_channel
      subscription
    end

    def server_check_channel_authorization_header(subscription_channel, access_token)
      headers = server_channel_header_list(subscription_channel, access_token)
      return if headers.nil?

      authorization_headers = headers.select { |header| channel_authorization_header?(header) }
      return if authorization_headers.length == 1 &&
                channel_authorization_header_matches?(authorization_headers.first, access_token)

      action = authorization_headers.empty? ? 'Added' : 'Replaced'
      add_message('warning', %(
        #{action} the Authorization header field with a Bearer token set to `#{access_token}` in the `header` field on
        the Subscription resource in order to connect successfully with the Inferno subscription channel.
      ))
      subscription_channel['header'] = (headers - authorization_headers) + ["Authorization: Bearer #{access_token}"]
    end

    def server_channel_header_list(subscription_channel, access_token)
      headers = subscription_channel['header']
      case headers
      when nil
        []
      when Array
        headers
      when String
        add_message('warning', %(
          The `header` field on the Subscription resource must be a list of strings. Inferno converted the single
          string value into a list containing that value.
        ))
        subscription_channel['header'] = [headers]
      else
        add_message('error', %(
          The `header` field on the Subscription resource must be a list of strings, so Inferno could not add the
          Authorization header field with a Bearer token set to `#{access_token}`.
        ))
        nil
      end
    end

    def channel_authorization_header?(header)
      header.is_a?(String) && header.split(':', 2).first.to_s.strip.casecmp?('authorization')
    end

    # Accepts only the canonical form, which notification header verification parses to the same name and value
    def channel_authorization_header_matches?(header, access_token)
      name, _separator, value = header.partition(': ')
      name.casecmp?('authorization') && value == "Bearer #{access_token}"
    end
  end
end
