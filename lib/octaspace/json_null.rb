# frozen_string_literal: true

module OctaSpace
  # Repairs for values the next API sometimes sends with the wrong JSON type.
  #
  # A missing value can arrive as the string "null" instead of JSON null: in
  # GPU statistics (price percentiles, TFLOPS) and in what nodes report about
  # their hardware (+mem_clock+, +power_limit+, +fan_speed+, …). Integer GPU
  # fields can also arrive as strings ("", "390"). Without these repairs one
  # misreporting node would break a whole listing.
  #
  # @api private
  module JsonNull
    module_function

    # Replaces every "null" string value (not object keys) with nil, in place.
    # Must not be applied where "null" can be real data, such as a session's
    # environment variables.
    # @return [Object] the same value
    def null_strings!(value)
      case value
      when Array
        value.map! { |item| (item == "null") ? nil : null_strings!(item) }
      when Hash
        value.each { |key, item| value[key] = (item == "null") ? nil : null_strings!(item) }
      end
      value
    end

    # @return [Integer, Float, nil] a numeric value as is; a numeric string as
    #   a number; anything else (blank, "null", text) as nil
    def number(value)
      case value
      when Numeric, nil then value
      when String
        text = value.strip
        if text.match?(/\A-?\d+\z/)
          text.to_i
        elsif text.match?(/\A-?\d+\.\d+\z/)
          text.to_f
        end
      end
    end

    # Normalizes integer fields of each GPU object of a machine listing, in place.
    # @param machines [Array<Hash>]
    # @param fields [Array<String>]
    def gpu_numbers!(machines, fields)
      Array(machines).each do |machine|
        next unless machine.is_a?(Hash)

        Array(machine["gpus"]).each do |gpu|
          next unless gpu.is_a?(Hash)

          fields.each { |field| gpu[field] = number(gpu[field]) if gpu[field].is_a?(String) }
        end
      end
      machines
    end
  end
end
