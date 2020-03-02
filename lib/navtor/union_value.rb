# typed: false
module Navtor
  class UnionValue
    # tagging for later type check using .accept_class?
    module UnionTag
    end

    def self.new (*classes, &block)
      class_names         = classes.map(&:name)
      helper_methods_name = class_names.map(&:demodulize).map(&:underscore)

      # helper methods to construct corresponding discriminated types
      def_helper_methods = helper_methods_name.zip(class_names).map do |method_name, klass|
        rb = <<~RUBY
        def self.#{ method_name } (data)
          arg = if #{ klass }.included_modules.include?(Value::ValueTag)
            #{ klass }.with data
          elsif #{ klass }.respond_to?(:new)
            #{ klass }.new data
          else
            data
          end

          self.new arg
        end
        RUBY
      end.join "\n"

      c = Class.new do
        include UnionTag

        const_set :KLASSESS, classes

        def self.new (data)
          idx         = self::KLASSESS.find_index { |klass| data.is_a? klass }
          class_names = self::KLASSESS.map(&:name).join ', '
          raise ArgumentError, "Invalid constructor argument. Allowed: #{ class_names }. But received #{ data.class.name }" if idx.nil?
          data
        end

        def self.accept_class? (klass)
          !self::KLASSESS.find_index { |k| klass <= k }.nil?
        end

        def self.inspect
          "Union ( #{ self::KLASSESS.map(&:name).join(', ') } )"
        end

        class_eval def_helper_methods

        class_eval &block if block
      end
    end
  end
end
