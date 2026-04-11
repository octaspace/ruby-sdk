# frozen_string_literal: true

module OctaSpace
  module Middleware
    # Thread-safe round-robin URL rotator with automatic failover
    #
    # When multiple base_urls are configured, requests are distributed
    # across all healthy URLs. Failed URLs enter a cooldown period before
    # being re-admitted to the rotation.
    #
    # @example
    #   rotator = OctaSpace::Middleware::UrlRotator.new([
    #     "https://api.octa.space",
    #     "https://api2.octa.space"
    #   ])
    #
    #   url = rotator.next_url
    #   rotator.mark_failed(url)
    #   rotator.stats # => { total: 2, available: 1, failed: ["https://api.octa.space"] }
    class UrlRotator
      # Seconds a failed URL is excluded from rotation
      FAILURE_COOLDOWN = 30

      # @param urls [Array<String>] ordered list of API base URLs
      def initialize(urls)
        @urls    = urls.dup.freeze
        @counter = 0
        @failed  = {}   # url => Time failed_at
        @mutex   = Mutex.new
      end

      # @return [String] next available URL (round-robin), falls back to first if all failed
      def next_url
        available = available_urls
        return @urls.first if available.empty?

        @mutex.synchronize do
          idx = @counter % available.size
          @counter += 1
          available[idx]
        end
      end

      # Mark a URL as temporarily failed
      # @param url [String]
      def mark_failed(url)
        @mutex.synchronize { @failed[url] = Time.now }
      end

      # Mark a URL as recovered (remove from failed list)
      # @param url [String]
      def mark_success(url)
        @mutex.synchronize { @failed.delete(url) }
      end

      # @return [Array<String>] currently healthy URLs (excluding cooldown)
      def available_urls
        now = Time.now
        @mutex.synchronize do
          @urls.reject do |url|
            failed_at = @failed[url]
            next false unless failed_at

            if now - failed_at < FAILURE_COOLDOWN
              true
            else
              @failed.delete(url)
              false
            end
          end
        end
      end

      # @return [Hash] diagnostic stats
      def stats
        {
          total:     @urls.size,
          available: available_urls.size,
          failed:    @mutex.synchronize { @failed.keys }
        }
      end

      # Reset state — useful in tests
      def reset!
        @mutex.synchronize do
          @counter = 0
          @failed.clear
        end
      end
    end
  end
end
