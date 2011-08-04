module Conducer
  class Base
  ##
  #      
    extend ActiveModel::Callbacks
    extend ActiveModel::Translation

    include ActiveModel::Conversion
    include ActiveModel::Naming
    include ActiveModel::AttributeMethods
    include ActiveModel::Serialization
    include ActiveModel::Dirty
    include ActiveModel::MassAssignmentSecurity
    include ActiveModel::Observing
    include ActiveModel::Validations::Callbacks
    include ActiveModel::Serializers::JSON
    include ActiveModel::Serializers::Xml
    include ActiveModel::Validations

  ## class_methods
  #
    class << Base
      def name(*args)
        return send('name=', args.first) unless args.empty?
        @name ||= super
      end

      def name=(name)
        @name = name.to_s
      end

      def model_name(*args)
        return send('model_name=', args.first) unless args.empty?
        @model_name ||= default_model_name
      end

      def model_name=(model_name)
        @model_name = model_name_for(model_name)
      end

      def model_name_for(model_name)
        ActiveModel::Name.new(Map[:name, model_name])
      end

      def default_model_name
        model_name_for(name.to_s.sub(/Conducer$/, ''))
      end

      def table_name
        @table_name ||= model_name.plural.to_s
      end
      alias_method('collection_name', 'table_name')

      def table_name=(table_name)
        @table_name = table_name.to_s 
      end
      alias_method('collection_name=', 'table_name=')

      def controller
        @controller ||= Conducer.controller
      end

      def controller=(controller)
        @controller = controller
      end
    end

  ## contructor 
  #
    %w(
      name
      attributes
      form
      new_record
      destroyed
    ).each{|a| fattr(a)}

    def self.new(*args, &block)
      conducer = allocate

      controllers, args = args.partition{|arg| arg.is_a?(ActionController::Base)}
      controller = controllers.shift #|| Conducer.controller || Conducer.mock_controller
      #conducer.controller = controller

      conducer.instance_eval do
        @name = self.class.model_name.singular
        @attributes = Attributes.new(self)
        @form = Form.new(self)

        @new_record = false
        @destroyed = false
      end

      conducer.send(:initialize, *args, &block)

      conducer
    end

    def initialize(attributes = {})
      attributes.each do |key, val|
        @attributes.set(key_for(key) => val)
      end
    end

  ## instance_methods
  #
    def id
      @attributes[:id] || @attributes[:_id]
    end

    def key_for(*keys)
      key = keys.flatten.join('.').strip
      key.split(%r/\s*[,.:_-]\s*/).map{|key| key =~ %r/^\d+$/ ? Integer(key) : key}
    end

    def [](key)
      @attributes.get(key_for(key))
    end

    def []=(key, val)
      @attributes.set(key_for(key), val)
    end

    %w( set get has? update ).each do |m|
      module_eval <<-__, __FILE__, __LINE__
        def #{ m }(*a, &b)
          @attributes.#{ m }(*a, &b)
        end
      __
    end

    def method_missing(method, *args, &block)
      case method.to_s
        when /^(.*)[=]$/
          key = key_for($1)
          val = args.first
          @attributes.set(key => val)

        when /^(.*)[!]$/
          key = key_for($1)
          val = true
          @attributes.set(key => val)

        when /^(.*)[?]$/
          key = key_for($1)
          @attributes.has?(key)

        else
          key = key_for(method)
          return @attributes.get(key) if @attributes.has?(key)
          super
      end
    end

    def inspect
      "#{ self.class.name }(#{ @attributes.inspect.chomp })"
    end

  # active_model support
  #
    def persisted?
      !(@new_record || @destroyed)
    end

    def self.human_attribute_name(attribute, options = {})
      attribute
    end

    def self.lookup_ancestors
      [self]
    end

    def read_attribute_for_validation(key)
      self[key]
    end

  # view support
  #
    url_helpers = Rails.application.try(:routes).try(:url_helpers)
    include(url_helpers) if url_helpers
    include(ActionView::Helpers) if defined?(ActionView::Helpers)

    def controller
      @controller
    end

    def controller=(controller)
      @controller = controller
    ensure
      default_url_options[:protocol] = @controller.request.protocol
      default_url_options[:host] = @controller.request.host
      default_url_options[:port] = @controller.request.port
    end

    controller_delegates = %w(
      render
      render_to_string
    )

    controller_delegates.each do |method|
      module_eval <<-__, __FILE__, __LINE__
        def #{ method }(*args, &block)
          controller.#{ method }(*args, &block)
        end
      __
    end

  # misc
  #
    def model_name
      self.class.model_name
    end

    def form
      @form
    end
  end
end
