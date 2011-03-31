## conduce -
#    be conducive to;
#    "The use of computers in the classroom lead to better writing"
#
# a model+view component for rails that combines the conductor and presenter
# pattern via a model capable of generating view-centric methods
#
# think of conducers as active_record objects - which they are - which can be
# adulterated with bits and pieces that make using them in a specific
# controller/views more streamlined.
#

## in a controller
#
#   @event = Conducer.for(:events).create!(params[:event])
#
 
## in a view
#
#   @event.link_to(:next, @event.next_event)
#
#   @event.render(:partial => 'shared/event', @event.attributes)
#


module Conducer
# version
#
  Conducer::VERSION = '0.0.2'

  def Conducer.version() Conducer::VERSION end

# base class
#
  class Base < (defined?(::ActiveRecord::Base) ? ::ActiveRecord::Base : Object)
    def Base.inherited(other, &block)
      other.module_eval(&::Conducer::Base::Methods)
      super
    end

    def Base.for(controller, *args, &block)
      new(controller, *args, &block)
    end

  # mixin used when building a conducer class
  #
    Methods = lambda do
      table_name = name.sub(/Conducer$/, '').underscore.pluralize
      set_table_name table_name

      def initialize(*args, &block)
        controllers, args = args.partition{|arg| arg.is_a?(ActionController::Base)}

        super(*args, &block)

        unless controllers.blank?
          controller = controllers.shift
          self.controller = controller
        else
          mock_controller!
        end
      end

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

    ## TODO - wtf - there must be an easier way....  please help.
    #
      def mock_controller!
        require 'action_dispatch/testing/test_request.rb'
        require 'action_dispatch/testing/test_response.rb'
        @store = ActiveSupport::Cache::MemoryStore.new
        @controller = ApplicationController.new
        @controller.perform_caching = true
        @controller.cache_store = @store
        @request = ActionDispatch::TestRequest.new
        @response = ActionDispatch::TestResponse.new
        @controller.request = @request
        @controller.response = @response
        @controller.send(:initialize_template_class, @response)
        @controller.send(:assign_shortcuts, @request, @response)
        @controller.send(:default_url_options).merge!(DefaultUrlOptions) if defined?(DefaultUrlOptions)
        default_url_options[:protocol] = @controller.request.protocol
        default_url_options[:host] = @controller.request.host
        default_url_options[:port] = @controller.request.port
        @controller
      end

      include Rails.application.routes.url_helpers
      include ActionView::Helpers

      %w( render render_to_string ).each do |method|
        module_eval <<-__
          def #{ method }(*args, &block)
            controller.#{ method }(*args, &block)
          end
        __
      end
    end
  end

# class/instance factory
#
#   conduer = Conducer.for(:events)
#
#   conduer = Conducer.for(Event){ has_one :location }
#
#   conducer = Conducer.for(:events, controller)
#
#   conducer = Conducer.for(Event, controller)
#
#   class EventConducer < Conducer::Base; end
#
#   conducer = EventConducer.for(controller)
#
  def for(*args, &block)
    first = args.first

    case first
      when String, Symbol, Class
        first = args.shift
        klass = class_for(first, &block)
        klass.new(*args)
      else
        klass = self
        klass.new(*args, &block)
    end
  end

# class factory
#
  def class_for(*args, &block)
    options = args.extract_options!.to_options!
    first = args.shift

    case first
      when String, Symbol
        base = ActiveRecord::Base
        table_name = first.to_s
        class_name = table_name.camelize.singularize
        model_name = class_name
        key = table_name

      when Class
        raise(ArgumentError, first.name) unless first < ActiveRecord::Base
        base = first
        table_name = base.table_name
        class_name = base.name
        model_name = base.model_name
        key = class_name

      else
        raise(ArgumentError, first.name)
    end

    klasses[key] ||= (
      Class.new(base){
        #module_eval(&Conducer::Base::Methods)

        set_table_name(table_name)

        singleton_class = class << self; self; end
        singleton_class.module_eval do
          define_method(:name){ class_name }
          define_method(:model_name){ model_name }
          define_method(:conducer_key){ key }
        end
      }
    )

    klass = klasses[key]
    klass.module_eval(&block) if block
    klass
  end

# track sub-classes
#
  def klasses
    @klasses ||= {}
  end

# put yer conducer's here
#
  def autoload_path
    File.join(Rails.root, 'app', 'conducers')
  end

  extend(self)
end

# mo betta the rails
#
  if defined?(Rails)
    class ActiveRecord::Base
      class << self
        def base(&block)
          this = self
          if block
            Class.new(ActiveRecord::Base){ set_table_name(this.table_name); module_eval(&block) }
          else
            @base ||= Class.new(ActiveRecord::Base){ set_table_name(this.table_name) }
          end
        end

        public(:relation)
      end
    end
  end

# autoload conducers
#
  if defined?(Rails)
    (Rails.configuration.autoload_paths += [Conducer.autoload_path]).uniq! unless Rails.configuration.autoload_paths.frozen?
  end

# protect against rails' too clever reloading
#
  if defined?(Rails)
    unloadable(Conducer)
  end

  BEGIN {
    Object.send(:remove_const, :Conducer) if defined?(Conducer)
  }
