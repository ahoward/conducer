# built-ins
#
  #require 'enumerator'
  #require 'set'

# dao libs
#
  module Conducer
    Version = '1.0.0' unless defined?(Version)

    def version
      Conducer::Version
    end

    def dependencies
      {
        'rails'       =>  [ 'rails'       , '~> 3.0.0' ],
        'map'         =>  [ 'map'         , '~> 4.3.0' ],
        'fattr'       =>  [ 'fattr'       , '~> 2.2.0' ],
        'tagz'        =>  [ 'tagz'        , '~> 9.0.0' ]
      }
    end

    def libdir(*args, &block)
      @libdir ||= File.expand_path(__FILE__).sub(/\.rb$/,'')
      args.empty? ? @libdir : File.join(@libdir, *args)
    ensure
      if block
        begin
          $LOAD_PATH.unshift(@libdir)
          block.call()
        ensure
          $LOAD_PATH.shift()
        end
      end
    end

    def load(*libs)
      libs = libs.join(' ').scan(/[^\s+]+/)
      Conducer.libdir{ libs.each{|lib| Kernel.load(lib) } }
    end

    extend(Conducer)
  end

# gems
#
  begin
    require 'rubygems'
  rescue LoadError
    nil
  end

  if defined?(gem)
    Conducer.dependencies.each do |lib, dependency|
      gem(*dependency)
      require(lib)
    end
  end

# cherry pick some rails' deps
#
  #active_record
  #action_mailer
  #rails/test_unit
  %w[
    action_controller
    active_resource
    active_support
  ].each do |framework|
    begin
      require "#{ framework }/railtie"
    rescue LoadError
    end
  end

  #blankslate.rb
  #instance_exec.rb
  #exceptions.rb
  #support.rb
  #slug.rb
  #stdext.rb
  #form.rb
  #db.rb
  #rails.rb

  Conducer.load %w[
    exceptions.rb
    instance_exec.rb
    support.rb
    attributes.rb
    form.rb
    validations.rb
    errors.rb
    base.rb
    db.rb
    crud.rb

    rails/engine.rb
  ]

# protect against rails' too clever reloading
#
  if defined?(Rails)
    unless defined?(unloadable)
      require 'active_support'
      require 'active_support/dependencies'
    end
    unloadable(Conducer)
  end

  BEGIN{ Object.send(:remove_const, :Conducer) if defined?(Conducer) }
