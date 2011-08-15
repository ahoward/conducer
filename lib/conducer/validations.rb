module Conducer
  module Validations
    class Error < Conducer::Error; end

    Conducer.load('validations/validator.rb')
    Conducer.load('validations/callback.rb')
    Conducer.load('validations/common.rb')
    #Conducer.load('validations/base.rb')

    ClassMethods = proc do
      def validator
        @validator ||= Validator.new(self)
      end

      def validations
        validator.validations
      end

      def validates(*args, &block)
        validator.add(*args, &block)
      end
    end

    InstanceMethods = proc do
      def validated?
        @validated = false unless defined?(@validated)
        @validated
      end

      def validated!
        @validated = true
      end

      def validate
        run_validations!
      end

      def validate!
        run_validations!
        raise Error.new("#{ self.class.name } is invalid!") unless valid?
        self
      end

      def validator
        self.class.validator
      end

      def run_validations!
        validator.run_validations!(self)
      end

      def is_valid=(boolean)
        @is_valid = !!boolean 
      end

      def is_valid(*bool)
        @is_valid ||= nil
        @is_valid = !!bool.first unless bool.empty?
        @is_valid
      end

      def valid!
        @forcing_validity = true
      end

      def forcing_validity?
        defined?(@forcing_validity) and @forcing_validity
      end

      def valid?(*args)
        if forcing_validity?
          true
        else
          options = Map.options_for!(args)
          validate if(options[:validate] or !validated?)
          errors.empty?
        end
      end
    end

    def Validations.included(other)
      other.send(:instance_eval, &ClassMethods)
      other.send(:class_eval, &InstanceMethods)
      other.send(:extend, Common)
      super
    end
  end
end
