require 'hana'
require_relative 'subscription_update_endpoint'

module SubscriptionsTestKit
  # Supports updates via JSON Patch (https://hl7.org/fhir/R4/http.html#patch). Other patch formats
  # (XML Patch and FHIRPath Patch) are not supported.
  class SubscriptionPatchEndpoint < SubscriptionUpdateEndpoint
    # Not inherited from SubscriptionUpdateEndpoint, so it must be declared here as well
    error_response_format :operation_outcome

    def requested_subscription_hash(current_subscription)
      unless request.content_type&.start_with?(JSON_PATCH_MIME_TYPE)
        fhir_error_response(415, 'not-supported',
                            "Inferno only supports JSON Patch requests with Content-Type '#{JSON_PATCH_MIME_TYPE}'")
        return
      end

      patch = parse_json_patch(request.body.string)
      if patch.nil?
        fhir_error_response(400, 'invalid', 'Request body is not a valid JSON Patch document')
        return
      end

      # Apply the patch to the Subscription as the client would see it on a read
      current_status = current_subscription_status_code(current_subscription)
      current_hash = current_subscription.source_hash.deep_dup.merge('status' => current_status)
      Hana::Patch.new(patch).apply(current_hash)
    rescue Hana::Patch::Exception, Hana::Pointer::Exception => e
      fhir_error_response(422, 'processing', "Unable to apply JSON Patch: #{e.message}")
      nil
    end

    def parse_json_patch(body)
      patch = JSON.parse(body)
      return unless patch.is_a?(Array) && patch.all? { |operation| valid_json_patch_operation?(operation) }

      patch
    rescue JSON::ParserError
      nil
    end

    # Checks the members each operation requires (https://datatracker.ietf.org/doc/html/rfc6902#section-4)
    # so that malformed operations are rejected here rather than raising non-patch errors when applied
    def valid_json_patch_operation?(operation)
      return false unless operation.is_a?(Hash) && operation['path'].is_a?(String)

      case operation['op']
      when 'add', 'replace', 'test'
        operation.key?('value')
      when 'move', 'copy'
        operation['from'].is_a?(String)
      else
        operation['op'] == 'remove'
      end
    end
  end
end
