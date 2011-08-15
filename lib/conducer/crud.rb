## CRUD support
#
  module Conducer
    module CRUD
      Code = proc do
        class << self
          def db
            Db.instance
          end

          def collection
            db[collection_name]
          end

          def all(*args)
            hashes = collection.all()
            hashes.map{|hash| new(hash)}
          end

          def find(id)
            hash = collection.find(id)
            new(hash) if hash
          end
        end

        def update_attributes(attributes = {})
          @attributes.set(attributes)
          @attributes
        end

        def update_attributes!(*args, &block)
          update_attributes(*args, &block)
        ensure
          save
        end

        def save(options = {})
          options.to_options!
          run_callbacks :save do
            unless valid?
              if options[:raise]
                raise!(:validation_error)
              else
                return(false)
              end
            end
            id = self.class.collection.save(@attributes)
            @attributes.set(:id => id)
            true
          end
        ensure
          @new_record = false
        end

        def save!
          save(:raise => true)
        end

        def destroy
          id = self.id
          if id
            self.class.collection.destroy(id)
            @attributes.rm(:id)
          end
          id
        ensure
          @destroyed = true
        end

        def reload
          id = self.id
          if id
            @attributes.clear
            conducer = self.class.find(id)
            @attributes.update(conducer.attributes) if conducer
          end
          self
        end
      end

      def CRUD.included(other)
        super
      ensure
        other.module_eval(&Code)
      end
    end
  end

## dsl for auto-crud
#
  module Conducer
    class Base
      class << self
        def crud
          include(Conducer::CRUD)
        end
        alias_method('crud!', 'crud')
      end
    end
  end
  #Conducer::Base.send(:include, Conducer::CRUD)
