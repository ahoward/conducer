if defined?(Rails)
  module Conducer
  ## support unloadable
  #
    def Conducer.before_remove_const
      #unload!
    end

  ##
  #
    class Engine < Rails::Engine
      GEM_DIR = File.expand_path(__FILE__ + '/../../../')
      ROOT_DIR = File.join(GEM_DIR, 'lib/conducer/rails')

      ### ref: https://gist.github.com/af7e572c2dc973add221

      paths.path = ROOT_DIR


    # yes yes, this should probably be somewhere else...
    #
      config.after_initialize do
        ActionController::Base.module_eval do

          before_filter do |controller|
          # set the conducer controller
          #
            Conducer.controller = controller

          # pre-parse any obvious conducer params
          #
            controller.instance_eval do
              Conducer.normalize_parameters(params)
            end
          end
        end
        
      end
    end
  end
end
