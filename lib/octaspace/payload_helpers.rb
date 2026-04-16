# frozen_string_literal: true

require "json"

module OctaSpace
  module PayloadHelpers
    module_function

    def parse_port_list(value)
      case value
      when nil
        []
      when Array
        value
      when String
        parse_stringified_port_list(value)
      else
        Array(value)
      end
    end

    def normalize_marketplace_bandwidth(value)
      numeric =
        case value
        when nil
          return nil
        when Numeric
          value.to_f
        when String
          Float(value)
        else
          return value
        end

      return numeric unless numeric > 100_000

      numeric / 125_000.0
    rescue ArgumentError, TypeError
      value
    end

    def parse_stringified_port_list(value)
      stripped = value.strip
      return [] if stripped.empty?

      parsed = JSON.parse(stripped)
      parsed.is_a?(Array) ? parsed : []
    rescue JSON::ParserError
      []
    end
    private_class_method :parse_stringified_port_list
  end
end
