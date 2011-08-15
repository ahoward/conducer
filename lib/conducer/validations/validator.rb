module Conducer
  module Validations
    class Validator
      NotBlank = lambda{|value| !value.to_s.strip.empty?} unless defined?(NotBlank)
      Cleared = 'Cleared'.freeze unless defined?(Cleared)

      attr_accessor :klass
      attr_accessor :validations

      def initialize(klass)
        @klass = klass
        @validations = Map.new
      end

      def add(*args, &block)
        options = Map.options_for!(args)
        block = args.pop if args.last.respond_to?(:call)
        block ||= NotBlank
        callback = Callback.new(options, &block)
        validations.set(args => Callback::Chain.new) unless validations.has?(args)
        validations.get(args).add(callback)
        callback
      end

      def run_validations!(conducer)
        run_validations(conducer)
      ensure
        conducer.validated! unless $!
      end

      def run_validations(conducer)
        errors = conducer.errors
        attributes = conducer.attributes
        attributes.extend(InstanceExec) unless attributes.respond_to?(:instance_exec)

        previous_errors = []
        new_errors = []

        errors.each_message do |keys, message|
          previous_errors.push([keys, message])
        end
        errors.clear!

        validations.depth_first_each do |keys, chain|
          chain.each do |callback|
            next unless callback and callback.respond_to?(:to_proc)

            number_of_errors = errors.size
            value = attributes.get(keys)
            returned =
              catch(:validation) do
                args = [value, attributes].slice(0, callback.arity)
                attributes.instance_exec(*args, &callback)
              end

            case returned
              when Hash
                map = Map(returned)
                valid = map[:valid]
                message = map[:message]

              when TrueClass, FalseClass
                valid = returned
                message = nil

              else
                any_errors_added = errors.size > number_of_errors
                valid = !any_errors_added
                message = nil
            end

            message ||= callback.options[:message]
            message ||= (value.to_s.strip.empty? ? 'is blank' : 'is invalid')

            unless valid
              new_errors.push([keys, message])
            else
              new_errors.push([keys, Cleared])
            end
          end
        end

        previous_errors.each do |keys, message|
          errors.add(keys, message) unless new_errors.assoc(keys)
        end

        new_errors.each do |keys, value|
          next if value == Cleared
          message = value
          errors.add(keys, message)
        end
      end
    end
  end
end
