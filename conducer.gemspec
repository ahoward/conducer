## conducer.gemspec
#

Gem::Specification::new do |spec|
  spec.name = "conducer"
  spec.version = "1.0.0"
  spec.platform = Gem::Platform::RUBY
  spec.summary = "conducer"
  spec.description = "description: conducer kicks the ass"

  spec.files =
["README",
 "Rakefile",
 "conducer.gemspec",
 "lib",
 "lib/conducer",
 "lib/conducer.rb",
 "lib/conducer/attributes.rb",
 "lib/conducer/base.rb",
 "lib/conducer/support.rb",
 "test",
 "test/active_model_lint_test.rb",
 "test/conducer_base_test.rb",
 "test/conducer_test.rb",
 "test/testing.rb"]

  spec.executables = []
  
  spec.require_path = "lib"

  spec.test_files = nil

### spec.add_dependency 'lib', '>= version'
#### spec.add_dependency 'map'

  spec.extensions.push(*[])

  spec.rubyforge_project = "codeforpeople"
  spec.author = "Ara T. Howard"
  spec.email = "ara.t.howard@gmail.com"
  spec.homepage = "https://github.com/ahoward/conducer"
end
