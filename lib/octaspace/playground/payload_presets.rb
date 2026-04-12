# frozen_string_literal: true

require "json"
require "yaml"

module OctaSpace
  module Playground
    module PayloadPresets
      module_function

      def all
        @all ||= load_presets
      end

      def fetch(key)
        all.fetch(key.to_s)
      end

      def payload_for(key)
        fetch(key).fetch(:payload)
      end

      def payload_json_for(key)
        JSON.pretty_generate(payload_for(key))
      end

      def reset!
        @all = nil
      end

      def path
        File.expand_path("payload_presets.yml", __dir__)
      end

      def load_presets
        raw = YAML.safe_load_file(path) || {}
        presets = raw.fetch("presets", {})

        presets.each_with_object({}) do |(key, value), memo|
          memo[key] = deep_symbolize(value)
        end
      end

      def deep_symbolize(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested), memo|
            memo[key.to_sym] = deep_symbolize(nested)
          end
        when Array
          value.map { |item| deep_symbolize(item) }
        else
          value
        end
      end

      private_class_method :load_presets, :deep_symbolize
    end
  end
end
