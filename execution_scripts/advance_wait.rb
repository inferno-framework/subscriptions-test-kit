#!/usr/bin/env ruby
# frozen_string_literal: true

# Advances an Inferno wait state by sending a GET request to the given URL.
# An optional delay can be specified to allow background jobs to complete
# before advancing (e.g. waiting for notifications to be delivered).
#
# Args:
#   ARGV[0] - url          (the wait URL to GET)
#   ARGV[1] - delay        (seconds to sleep before advancing, default: 0)

require 'faraday'

url   = ARGV[0]
delay = ARGV[1].to_i

raise "Usage: #{$PROGRAM_NAME} <url> [delay_seconds]" if url.nil?

if delay > 0
  puts "Waiting #{delay}s for notifications to be delivered..."
  sleep delay
end

puts "Advancing wait: #{url}"
uri      = URI(url)
response = Net::HTTP.new(uri.host, uri.port).request(Net::HTTP::Get.new(uri.request_uri))
puts "Response: #{response.code}"
