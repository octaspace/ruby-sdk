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
