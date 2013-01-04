require "active_model"
require "active_support"

require "map"
require "arrayfields"
require "coerce"
require "fattr"

begin
  require "ffi-uuid"
rescue LoadError
  begin
    require "uuidtools"
  rescue LoadError
    begin
      require "uuid"
    rescue LoadError
      raise "could not load ffi-uuid | uuidtools | uuid"
    end
  end
end

require "rails_helper"
require "rails_errors2html"

class Conducer
  def Conducer.for(model_or_name, *args, &block)
    options = Map.options_for(args)
    options.pop

    model =
      if model_or_name.respond_to?(:model_name)
        build_wrapper_model_for(model_or_name, &block)
      else
        build_named_model_for(model_or_name, &block)
      end

    if options.has_key?(:model_name)
      model.model_name(options[:model_name])
    end

    model
  end

  def Conducer.build_wrapper_model_for(model, &block)
    Class.new(model).class_eval do
      singleton_class = class << self; self; end

      singleton_class.module_eval do
        def model_name(*args)
          self.model_name = args.join unless args.empty?
          @model_name ||= ::Conducer::Model.model_name_for(self.name)
        end

        def model_name=(model_name)
          @model_name = ::Conducer::Model.model_name_for(model_name)
        end
      end

      self.model_name(model.model_name)

      if model.respond_to?(:table_name)
        self.set_table_name(model.table_name)
      end

      if model.respond_to?(:base_class)
        singleton_class.send(:define_method, :base_class){ model.base_class }
      end

      if model.respond_to?(:default_collection_name)
        self.default_collection_name = model.default_collection_name
      end

      if model.respond_to?(:hereditary?)
        singleton_class.send(:define_method, :hereditary?){ false }
        define_method(:hereditary?){ self.class.hereditary? }
      end

      include Conducer::Common

      model.class_eval do
        alias_method :__initialize__, :initialize

        def initialize(*args, &block)
          super
        ensure
          @errors = ::Conducer::Errors.new(self)
        end
      end

      class_eval(&block) if block

      self
    end
  end

  def Conducer.build_named_model_for(name, &block)
    Class.new(Model).class_eval do
      self.model_name = name.to_s.camelize

      include Conducer::Common

      class_eval(&block) if block

      self
    end
  end

  def Conducer.uuid
    @uuids ||= []

    if @uuids.empty?
      n = 128

      uuids =
        case
          when defined?(FFI::UUID)
            FFI::UUID.get_uuids(n, :time)

          when defined?(UUIDTools::UUID)
            Array.new(n){ UUIDTools::UUID.timestamp_create }

          when defined?(UUID)
            generator = UUID.new
            Array.new(n){ generator.generate }
        end

      @uuids.push(*uuids)
    end

    @uuids.shift.to_s
  end

##
#
  module Common
    if defined?(Helper)
      def helper
        @helper ||= Helper.new
      end
    end
  end

##
#
  class Errors < ::ActiveModel::Errors
    include Errors2Html

    def relay(other)
      errors = other.respond_to?(:errors) ? other.errors : other.to_hash

      errors.each do |key, values|
        Array(values).each do |message|
          add(key, message)
          Array(self[key]).uniq!
        end
      end
    end
  end

##
#
  class Model
  ##
  #
    def Model.inherited(other)
      Model.ify(other)
      super
    end

    def Model.ify(other)
      other.send :class_eval do
        include ActiveModel::Conversion
        extend ActiveModel::Naming
        include ActiveModel::Validations
        include ActiveModel::Serialization
        extend ActiveModel::Callbacks

        instance_eval &ClassMethods
        class_eval &InstanceMethods

        define_model_callbacks(:create, :update, :save, :destroy, :initialize)
      end

      other.send :class_eval do
        identifier(:id){ Conducer.uuid }
      end
    end

  ##
  #
    ClassMethods = proc do
      def model_name(*args)
        self.model_name = args.join unless args.empty?
        @model_name ||= Model.model_name_for(self.name)
      end

      def model_name=(model_name)
        @model_name = Model.model_name_for(model_name)
      end

      def fields
        @fields ||= Array.fields
      end

      def field(*args, &block)
        field = Field.new(self, *args, &block)

        name = field.name.to_s
        key = name.inspect

        class_eval <<-__, __FILE__, __LINE__

          def #{ name }
            attributes[#{ key }]
          end

          def #{ name }?
            !!attributes[#{ key }]
          end

          def #{ name }=(value)
            field = model.class.fields[#{ key }]
            attributes[#{ key }] = value.nil? ? nil : field.cast(value)
          end

        __

        fields[name] = field
      end

      def table
        @table ||= Map.new
      end

      def all
        table.values
      end

      def first
        table.values.first
      end

      def last
        table.values.last
      end

      def find(id)
        table[id]
      end

      def where(&block)
        all.select(&block)
      end

      def create(*args, &block)
        model = new(*args, &block)
        model.save ? model : false
      end

      def create!(*args, &block)
        model = new(*args, &block)
        model.save!
        model
      end

      def identifier(*args, &block)
        field = fields.detect{|f| f.identifier?}

        unless args.blank?
          fields.delete(field) if field

          field = self.field(*args, &block)

          field.identifier = true
          fields.delete(field)
          fields.unshift(field)

          validates_presence_of(field.name)
        end

        field.name if field
      end

      def identifier?
        !!fields.detect{|f| f.identifier?}
      end

      def identifier=(identifier)
        self.identifier(identifier)
      end
    end

  ##
  #
    InstanceMethods = proc do
      fattr :attributes
      fattr :persisted
      fattr :destroyed
      fattr :built

      def initialize(*args, &block)
        attributes = Map.options_for(args)
        attributes.pop

        args.each_with_index do |arg, index|
          field = self.class.fields[index]
          raise IndexError unless field
          attributes[field.name] = arg
        end

        @attributes = Map.new
        @persisted = false
        @destroyed = false
        @built = false
        @block = block

        set_defaults

        @errors = Errors.new(self)

        update_attributes(attributes)
      end

      def model
        self
      end

      def build
        return true if @built
        build!
        @built = true
        self
      end

      def build!(&block)
        b = block || @block
        instance_eval(&b) if b
        self
      end

      def save
        run_callbacks(:save) do
          build!
          valid = valid?
          persist! if valid
          valid
        end
      end

      def save!
        run_callbacks(:save) do
          build!
          valid? or raise 'invalid!'
        end
      end

      def persist!
        if identifier?
          id = send(identifier)

          unless id
            id = Conducer.uuid
            send("#{ identifier }=", id)
          end

          self.class.table[id] = self

          @persisted = true
          id
        else
          false
        end
      end

      def destroy
        run_callbacks(:destroy) do
          desist!
          true
        end
      end

      def destroy!
        destroy
      end

      def desist!
        if identifier?
          key = send(identifier)
          self.class.table.delete(key)
          @destroyed = true
          key
        else
          false
        end
      end

      def update_attributes(attributes = {})
        Map.for(attributes).each do |name, value|
          setter = "#{ name }="

          if respond_to?(setter)
            send(setter, value)
          else
            @attributes[name] = value
          end
        end
      end

      def set_defaults
        self.class.fields.each do |field|
          if field.default?
            field.set_default(self)
          else
            attributes[field.name] = nil
          end
        end
      end

      def inspect
        "#{ model.class.name }(#{ {}.update(model.attributes).inspect })"
      end

      def method_missing(method, *args, &block)
        name = method.to_s
        op = nil

        if matched = %r/\A(.*)([=?!])\Z/iomx.match(name).to_a[1..-1]
          name, op, *ignored = matched
        end

        case op
          when '='
            if args.empty?
              super
            else
              value = args.shift
              @attributes[name] = value
            end

          when '?'
            if args.empty? and block.nil? and @attributes.has_key?(name)
              !!@attributes[name]
            else
              super
            end

          when '!'
            if args.empty? and block.nil? and @attributes.has_key?(name)
              @attributes[name] = !!!@attributes[name]
            else
              super
            end

          else
            if args.empty? and block.nil? and @attributes.has_key?(name)
              @attributes[name]
            else
              super
            end
        end
      end

      def persisted!(boolean = true)
        @persisted = !!boolean
      end

      def destroyed!(boolean = true)
        @destroyed = !!boolean
      end

      def model_name
        self.class.model_name
      end

      def fields
        model.class.fields.map{|field| field.on(model)}
      end

      def identifier
        self.class.identifier
      end

      def identifier?
        self.class.identifier?
      end

      def to_param
        if identifier?
          send(identifier)
        else
          raise IndexError
        end
      end
    end

  ##
  #
    class Field
      fattr :model
      fattr :name
      fattr :value
      fattr :type
      fattr :default
      fattr :block
      fattr :identifier

      def initialize(model, *args, &block)
        @model = model

        options = Map.for(options)

        @name = (args.shift || options[:name]).to_s
        @type = options[:type].to_s.downcase if options[:type]
        @identifier = !!options[:identifier]
        @value = nil

        if options[:default] || block
          @default = options[:default] || block
        end
      end

      def get
        value
      end

      def getter
        name
      end

      def set(value)
        @value = cast(value)
      end

      def setter
        "#{ name }="
      end

      def on(model)
        dup.tap{|field| field.value = model.send(field.name)}
      end

      def default?
        defined?(@default)
      end

      def set_default(model)
        value = default.respond_to?(:to_proc) ? model.instance_eval(&default.to_proc) : default

        default_value =
          begin
            case
              when value.respond_to?(:dup)
                value.dup
              when value.respond_to?(:clone)
                value.clone
              else
                value
            end
          rescue TypeError
            value
          end

        model.send(setter, default_value)
      end

      def Field.cast(type, value)
        Coerce.send(type, value)
      end

      def cast(value)
        @type ? Field.cast(@type, value) : value
      end

      def inspect
        "#{ name }:#{ value.inspect }"
      end
    end

  ##
  #
    def Model.model_name_for(name)
      responds_to_name = Map.new(:name => name.to_s.camelize)
      ActiveModel::Name.new(responds_to_name)
    end
  end
end



if $0 == __FILE__


  A = Conducer.for(:A) do
    field :title
    validates_presence_of :title
  end
  a = A.new

  a.foo=42
  a.errors.add :base, 'foo is fucked'
  puts a.errors

  require 'pry'
  binding.pry

end

