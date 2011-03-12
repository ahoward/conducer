## conducer.gemspec
#

Gem::Specification::new do |spec|
  spec.name = "conducer"
  spec.version = "0.0.1"
  spec.platform = Gem::Platform::RUBY
  spec.summary = "conducer"
  spec.description = "description: conducer kicks the ass"

  spec.files = ["lib", "lib/conducer.rb", "Rakefile"]
  spec.executables = []
  
  spec.require_path = "lib"

  spec.has_rdoc = true
  spec.test_files = nil

# spec.add_dependency 'lib', '>= version'

  spec.extensions.push(*[])

  spec.rubyforge_project = "codeforpeople"
  spec.author = "Ara T. Howard"
  spec.email = "ara.t.howard@gmail.com"
  spec.homepage = "http://github.com/ahoward/conducer"
end
