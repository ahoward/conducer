Testing Conducer::Base do
##
#
  testing 'that base classes can be constructed and named' do
    new_foo_conducer_class()
  end

##
#
  testing 'that basic validations/errors work' do
    c =
      assert{
        new_foo_conducer_class do
          validates_presence_of :bar
          validates_presence_of 'foo.bar'
        end
      }

    o = assert{ c.new }
    assert{ !o.valid? }
    assert{ !Array(o.errors['bar']).empty? }
    assert{ !Array(o.errors['foo.bar']).empty? }

    o.attributes.set :foo, :bar, 42
    assert{ !o.valid? }
    assert{ Array(o.errors['foo.bar']).empty? }
  end

##
#
  testing 'that basic form elements work' do
    c =
      assert{
        new_foo_conducer_class do
          validates_presence_of :bar
        end
      }

    o = assert{ c.new }
    assert{ o.form }
    assert{ o.form.input(:foo) }
    assert{ o.form.input(:bar) }
  end

##
#
  testing 'that a conducers support basic CRUD' do
    o = new_foo_conducer(:k => :v)

  # create
    id = assert{ o.save }
    assert{ db.foos.find(id)[:k] == o.attributes[:k] }
    assert{ id == o.id }

  # update
    t = Time.now
    assert{ o.update_attributes :t => t }
    assert{ o.save }
    assert{ o.reload }
    assert{ o.attributes.t == t }

  # destroy
    assert{ o.destroy }
    assert{ db.foos.find(id).nil? }
  end

  

protected
  def new_foo_conducer_class(&block)
    name = 'FooConducer'
    c = assert{ Class.new(Conducer::Base){ self.name = name } }
    assert{ c.name == 'FooConducer' }
    assert{ c.model_name == 'Foo' }
    assert{ c.table_name == 'foos' && c.collection_name == 'foos' }
    assert{ c.module_eval(&block); true } if block
    c
  end

  def new_foo_conducer(*args, &block)
    assert{ new_foo_conducer_class(&block).new(*args) }
  end

  prepare do
    $db = Conducer::Db.new(:path => 'test/db.yml')
    Conducer::Db.instance = $db
    collection = $db['foos']
    %w( a b c ).each do |name|
      collection.save(
        :name => name, :created_at => Time.now.to_f, :a => %w( x y z ), :h => {:k => :v}
      )
    end
  end

  cleanup do
    $db = Conducer::Db.new(:path => 'test/db.yml')
    $db.rm_f
  end

  def db
    $db
  end

  def collection
    $db[:foos]
  end
end


BEGIN {
  testdir = File.dirname(File.expand_path(__FILE__))
  rootdir = File.dirname(testdir)
  libdir = File.join(rootdir, 'lib')
  require File.join(libdir, 'conducer')
  require File.join(testdir, 'testing')
}
