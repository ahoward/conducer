module Conducer
  def current_controller(*args)
    @current_controller = args.first unless args.empty?
    @current_controller
  end
  alias_method('controller', 'current_controller')

  def current_controller=(current_controller)
    @current_controller = current_controller
  end
  alias_method('controller=', 'current_controller=')

  Fattr(:root){ Rails.root || '.' }

  def key_for(*keys)
    key = keys.flatten.join('.').strip
    key.split(%r/\s*[,.:_-]\s*/).map{|key| key =~ %r/^\d+$/ ? Integer(key) : key}
  end

  def mock_controller
    ensure_rails_application do
      require 'action_dispatch/testing/test_request.rb'
      require 'action_dispatch/testing/test_response.rb'
      store = ActiveSupport::Cache::MemoryStore.new
      controller = defined?(ApplicationController) ? ApplicationController.new : ActionController::Base.new
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

  def ensure_rails_application(&block)
    if Rails.application.nil?
      mock = Class.new(Rails::Application)
      Rails.application = mock.instance
      begin
        block.call()
      ensure
        Rails.application = nil
      end
    else
      block.call()
    end
  end

  def normalize_parameters(params)
    conducer = (params.delete('conducer') || {}).merge(params.delete(:conducer) || {})

    unless conducer.blank?
      conducer.each do |key, paths_and_values|
        params[key] = nil
        next if paths_and_values.blank?

        map = Map.new

        paths_and_values.each do |path, value|
          keys = keys_for(path)
          map.set(keys => value)
        end

        params[key] = map
      end
    end

    params[:conducer] = :normalized
    params
  end

  def keys_for(keys)
    keys.strip.split(%r/\s*[,._-]\s*/).map{|key| key =~ %r/^\d+$/ ? Integer(key) : key}
  end

  def db(*args, &block)
    Db.instance
  end
end
