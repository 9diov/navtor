# Simple immutable value objects for ruby.
#
# @example Make a new value class:
#   Point = Value.new(:x, :y)
#
# @example And use it:
#   p = Point.new(1, 0)
#   p.x
#   #=> 1
#   p.y
#   #=> 0
#
require 'navtor/union_value'

class Hash
  def compact
    self.to_a.select {|x, y| !y.nil?}.to_h
  end
end

module Navtor
  class Utils
    def self.assert_type(var, expected_type, var_name=nil)
      correct_type = if expected_type.included_modules.include? UnionValue::UnionTag
                       expected_type.accept_class? var.class
                     else
                       var.is_a? expected_type
                     end
      raise InvalidParameter.new("#{ var_name || 'Input' } must be a #{ expected_type.inspect }. Received #{ var.class }") unless correct_type
    end
  end

  class ValueClass; end

  class Value
    module ValueTag
    end

    # Create a new value class.
    #
    # @param  [Array<Symbol>] fields  Names of fields to create in the new value class
    # @param  [Proc]          block   Optionally, a block to further define the new value class
    # @return [Class]                 A new value class with the provided `fields`
    # @raise  [ArgumentError]         If no field names are provided
    def self.new(*fields, &block)
      raise ArgumentError.new('wrong number of arguments (0 for 1+)') if fields.empty?
      types = {}
      fields = fields.inject([]) do |res, field|
        if field.is_a?(Symbol) || field.is_a?(String)
          res + [field]
        elsif field.is_a?(Hash)
          types = types.merge(field)
          res + field.keys
        end
      end

      Class.new(ValueClass) do
        include ValueTag

        attr_reader(:hash, *fields)

        # Unroll the fields into a series of assignment Ruby statements that can
        # be used inside of the initializer for the new class. This was introduced
        # in PR#56 as a performance optimization -- it ensures that this iteration
        # happens once per class, instead of happening once per instance of the
        # class.
        instance_var_assignments = Array.new(fields.length) do |idx|
          "@#{fields[idx]} = values[#{idx}]"
        end.join("\n")

        class_eval <<-RUBY
        def initialize(*values)
          if #{fields.size} != values.size
            raise ArgumentError.new("wrong number of arguments, \#{values.size} for #{fields.size}")
          end

          #{instance_var_assignments}
          self._validate_types
          self._validate
          self._initialize(*values)

          @hash = self.class.hash ^ values.hash

          freeze
        end
        RUBY

        const_set :VALUE_ATTRS, fields
        const_set :TYPE_ATTRS, types
        class_variable_set(:@@defaults, {})

        def self.with(hash)
          hash = hash.to_h if hash.is_a?(ValueClass)
          unexpected_keys = hash.keys - self::VALUE_ATTRS
          if unexpected_keys.any?
            raise ArgumentError.new("Unexpected hash keys: #{unexpected_keys}")
          end

          missing_keys = self::VALUE_ATTRS - (hash.keys + self.defaults.keys)
          if missing_keys.any?
            raise ArgumentError.new("Missing hash keys: #{missing_keys} (got keys #{hash.keys})")
          end
          hash = self.class_variable_get(:@@defaults).merge(hash.compact)

          new(*hash.values_at(*self::VALUE_ATTRS))
        end

        def self.loose_with(hash)
          missing_keys = self::VALUE_ATTRS - hash.keys
          if missing_keys.any?
            raise ArgumentError.new("Missing hash keys: #{missing_keys} (got keys #{hash.keys})")
          end

          new(*hash.values_at(*self::VALUE_ATTRS))
        end

        def self.defaults(defaults=nil)
          return self.class_variable_get(:@@defaults) if defaults.nil?

          self.class_variable_set(:@@defaults, defaults)
          self
        end

        def merge(hash)
          hash = self.to_h.merge(hash)
          self.class.with(hash)
        end

        def self.with_default (hash = {})
          loose_with self.class_variable_get(:@@defaults).merge(hash.compact)
        end

        def [] (key)
          raise ArgumentError.new("Invalid key: #{ key }. Allowed: #{ self.class::VALUE_ATTRS }") unless self.class::VALUE_ATTRS.include?(key)
          self.send key
        end

        def ==(other)
          eql?(other)
        end

        def eql?(other)
          self.class == other.class && _values == other._values
        end

        def _values
          self.class::VALUE_ATTRS.map { |field| send(field) }
        end

        def inspect
          attributes = to_a.map { |field, value| "#{field}=#{value.inspect}" }.join(', ')
          "#<#{self.class.name} #{attributes}>"
        end

        def pretty_print(q)
          q.group(1, "#<#{self.class.name}", '>') do
            q.seplist(to_a, lambda { q.text ',' }) do |pair|
              field, value = pair
              q.breakable
              q.text field.to_s
              q.text '='
              q.group(1) do
                q.breakable ''
                q.pp value
              end
            end
          end
        end

        def with(hash = {})
          hash = hash.to_h if hash.is_a?(ValueClass)
          return self if hash.empty?
          self.class.with(to_h.merge(hash))
        end

        def to_h
          Hash[to_a]
        end

        def to_hash
          to_h
        end

        def to_json
          to_h.to_json
        end

        def as_json(options = {})
          to_h
        end

        def recursive_to_h
          Hash[to_a.map { |k, v| [k, Value.coerce_to_h(v)] }]
        end

        def to_a
          self.class::VALUE_ATTRS.map { |field| [field, send(field)] }
        end

        def to_ary
          self.class::VALUE_ATTRS.map { |field| send(field) }
        end

        def _validate_types
          self.class::TYPE_ATTRS.each do |k, v|
            Utils.assert_type(send(k), v, k.to_s)
          end
        end

        def _validate
          # To be overridden by child class
        end

        def _initialize(*values)
          # To be overridden by child class
        end

        def to_ary
          self.class::VALUE_ATTRS.map {|field| send(field)}
        end

        def to_s
          inspect
        end

        def to_ruby
          attributes = to_a.map { |field, value| "#{field}: #{value.respond_to?(:to_ruby) ? value.to_ruby : value.inspect}" }.join(",\n")
          "#{self.class.name}.with(\n#{attributes}\n)"
        end

        def self.slice(*fields)
          typed_fields = self::TYPE_ATTRS.slice(fields)
          new_class_fields = (self::VALUE_ATTRS & fields) - typed_fields.keys + [typed_fields]
          Value.new(*new_class_fields).defaults(self.defaults.slice(fields))
        end

        # Create new object from anonymous class by using only `fields`
        #
        # Example:
        #   Point = Value.new(:x, :y, :label)
        #   point = Point.with(1, 2, 'point')
        #   point2 = point.slice(:x, :y)
        #   point2.x == point.x
        #   point2.label # Raise NoMethodError
        def slice(*fields)
          self.class.slice(*fields).with(self.to_h.slice(*fields))
        end

        def diff(value)
          HashDiff.diff(self.to_h, value.to_h)
        end

        class_eval &block if block
      end
    end

    protected

    def self.coerce_to_h(v)
      case
      when v.is_a?(Hash)
        Hash[v.map { |hk, hv| [hk, coerce_to_h(hv)] }]
      when v.respond_to?(:map)
        v.map { |x| coerce_to_h(x) }
      when v && v.respond_to?(:to_h)
        v.to_h
      else
        v
      end
    end
  end
end
