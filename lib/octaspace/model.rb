# frozen_string_literal: true

module OctaSpace
  # Read-only view over a JSON object returned by the API.
  #
  # Declared attributes get reader methods; nested objects and arrays of
  # objects are wrapped in their own model classes. Fields the SDK does not
  # know yet are kept and reachable with {#[]} and {#to_h}, so a new field in
  # the API (it is in active development) never breaks parsing.
  #
  # @example
  #   machine = client.compute.list.first
  #   machine.node_number      # => "7KQ4-M2XD-4"
  #   machine.gpus.first.model # => "NVIDIA GeForce RTX 3090"
  #   machine[:new_field]      # => value of a field the SDK has no reader for
  #   machine.to_h             # => the JSON object as parsed
  class Model
    class << self
      # Declares attributes with reader methods.
      # @param names [Array<Symbol>]
      # @param model [Class, nil] wrap a nested object (or each element of an array) in this model
      # @param many [Boolean] the value is an array of objects; nil reads as []
      def attribute(*names, model: nil, many: false)
        names.each do |name|
          key = name.to_s
          attribute_names << name
          if model
            define_method(name) { nested(key, model, many) }
          else
            define_method(name) { @data[key] }
          end
        end
      end

      # Hides the values of these attributes in #inspect (URLs that grant access).
      def redact(*names)
        redacted_names.concat(names)
      end

      # @return [Array<Symbol>]
      def redacted_names
        @redacted_names ||= []
      end

      # @return [Array<Symbol>] declared attribute names
      def attribute_names
        @attribute_names ||= []
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@attribute_names, attribute_names.dup)
        subclass.instance_variable_set(:@redacted_names, redacted_names.dup)
      end

      # Wraps a JSON object; anything else (nil, a scalar) is returned as is.
      def wrap(value)
        value.is_a?(Hash) ? new(value) : value
      end

      # Wraps each JSON object of an array; nil becomes an empty array.
      def wrap_all(values)
        Array(values).map { |value| wrap(value) }
      end
    end

    # @param data [Hash] JSON object with string keys
    def initialize(data = {})
      @data = data.to_h.transform_keys(&:to_s)
      @nested = {}
    end

    # Value of any field, including ones without a reader
    # @param key [String, Symbol]
    def [](key) = @data[key.to_s]

    # @param key [String, Symbol]
    # @return [Boolean] whether the API sent this field (it may be null)
    def key?(key) = @data.key?(key.to_s)

    # @return [Hash] the JSON object as parsed (string keys, nested values unwrapped)
    def to_h = @data

    # Pattern matching support: +in {node_number:, base_price:}+
    def deconstruct_keys(keys)
      (keys || @data.keys.map(&:to_sym)).to_h { |key| [key, respond_to?(key) ? public_send(key) : @data[key.to_s]] }
    end

    def ==(other)
      other.instance_of?(self.class) && other.to_h == to_h
    end
    alias_method :eql?, :==

    def hash = [self.class, @data].hash

    def inspect
      shown = self.class.attribute_names.filter_map do |name|
        value = @data[name.to_s]
        next if !@data.key?(name.to_s) || value.is_a?(Enumerable)

        "#{name}=#{(value && self.class.redacted_names.include?(name)) ? "[REDACTED]" : value.inspect}"
      end
      "#<#{self.class.name} #{shown.join(" ")}>"
    end
    alias_method :to_s, :inspect

    private

    def nested(key, model, many)
      return @nested[key] if @nested.key?(key)

      value = @data[key]
      @nested[key] = (many || value.is_a?(Array)) ? model.wrap_all(value) : model.wrap(value)
    end
  end
end
