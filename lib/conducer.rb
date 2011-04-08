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

## in app/conducers/event_conducer.rb
#
#   class CommentConducer < Conducer::Base
#     belongs_to :post
#   
#     def link_to_post
#       link_to('post', post)
#     end
#   end
 
## in a view
#
#   @event.link_to(:next, @event.next_event)
#
#   @event.render(:partial => 'shared/event', @event.attributes)
#


module Conducer
## version
#
  Conducer::VERSION = '0.0.2'

  def Conducer.version
    Conducer::VERSION
  end

## module methods
#
  class << Conducer
  ## include the ability to track the current controller - hook into this like so
  #
  # class ApplicationController
  #   before_filter do |controller|
  #     Conducer.controller = controller
  #   end
  # end
  #
    attr_accessor :controller

    def mock_controller
      require 'action_dispatch/testing/test_request.rb'
      require 'action_dispatch/testing/test_response.rb'
      store = ActiveSupport::Cache::MemoryStore.new
      controller = ApplicationController.new
      controller.perform_caching = true
      controller.cache_store = store
      request = ActionDispatch::TestRequest.new
      response = ActionDispatch::TestResponse.new
      controller.request = request
      controller.response = response
      controller.send(:initialize_template_class, response)
      controller.send(:assign_shortcuts, request, response)
      controller.send(:default_url_options).merge!(DefaultUrlOptions) if defined?(DefaultUrlOptions)
      controller
    end
  end


## the conducer base class and mixin
#
  class Base < (defined?(::ActiveRecord::Base) ? ::ActiveRecord::Base : Object)
    def Base.inherited(other, &block)
      other.module_eval(&::Conducer::Base::Mixin)
      super
    end

    def Base.for(controller, *args, &block)
      new(controller, *args, &block)
    end

  ## mixin used when building a conducer class
  #
    Mixin = lambda do
      class << self
        def name
          @name ||= super
        end

        def name=(name)
          @name = name.to_s
        end

        def model_name
          @model_name ||= super
        end

        def model_name=(model_name)
          klass = self.dup
          klass.name = model_name.to_s
          @model_name = ActiveModel::Name.new(klass)
        end

        def table_name
          super
        end

        def table_name=(table_name)
          set_table_name(table_name)
        end

        def conducer_key
          @conducer_key ||= name
        end

        def conducer_key=(conducer_key)
          @conducer_key = conducer_key.to_s
        end
      end

    ## support for conducers, located in app/conducers/*, with names like PostConducer
    #
      if name =~ /^(.*)Conducer$/
        self.model_name = $1
        self.table_name = model_name.underscore.pluralize
      end

      def initialize(*args, &block)
        controllers, args = args.partition{|arg| arg.is_a?(ActionController::Base)}
        super(*args, &block)
        self.controller = controllers.shift || Conducer.controller || Conducer.mock_controller
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

      include Rails.application.routes.url_helpers
      include ActionView::Helpers

      delegates = %w(
        render
        render_to_string
      )

      delegates.each do |method|
        module_eval <<-__, __FILE__, __LINE__
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

# class factory - used to build a conducer class around an existing class or
# against a particular table_name
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
        conducer_key = table_name

      when Class
        raise(ArgumentError, first.name) unless first < ActiveRecord::Base
        base = first
        table_name = base.table_name
        class_name = base.name
        model_name = base.model_name
        conducer_key = class_name

      else
        raise(ArgumentError, first.name)
    end

    cache[conducer_key] ||= (
      Class.new(base){
        module_eval(&Conducer::Base::Mixin)

        self.name = class_name
        self.table_name = table_name
        self.model_name = model_name
        self.conducer_key = conducer_key
      }
    )

    conducer = cache[conducer_key]
    conducer.module_eval(&block) if block
    conducer
  end

# track sub-classes
#
  def cache
    @cache ||= {}
  end

# put yer conducers in app/conducers/foo_conducer.rb... 
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
