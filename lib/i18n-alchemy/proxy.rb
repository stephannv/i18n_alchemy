module I18n
  module Alchemy
    class Proxy
      class Attribute
        attr_reader :attribute

        def initialize(target, attribute, parser)
          @target    = target
          @attribute = attribute
          @parser    = parser
        end

        def read(method, *args, &block)
          value = @target.send(method, *args, &block)
          @parser.localize(value)
        end

        def write(method, value, *args, &block)
          value = @parser.parse(value)
          @target.send(method, value, *args, &block)
        end
      end

      def initialize(target)
        @target = target

        @attributes = @target.class.columns.map do |column|
          next if column.primary

          parser = if column.number?
            I18n::Alchemy::NumericParser
          elsif column.type == :date
            I18n::Alchemy::DateParser
          end

          # TODO: this is gonna create a parser for each attribute, is this
          # really required?
          Attribute.new(@target, column.name, parser.new) if parser
        end.compact
      end

      def method_missing(method, *args, &block)
        attribute = method.to_s
        is_writer = attribute.ends_with?("=")
        attribute = attribute.delete("=")
        column    = find_localized_column(attribute)

        if column
          if is_writer
            column.write(method, args.shift, *args, &block)
          else
            column.read(method, *args, &block)
          end
        else
          @target.send(method, *args, &block)
        end
      end

      def respond_to?(*args)
        @target.respond_to?(*args)
      end

      private

      def find_localized_column(attribute)
        @attributes.detect { |c| c.attribute == attribute }
      end
    end
  end
end
