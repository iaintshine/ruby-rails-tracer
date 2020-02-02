# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "rails-tracer"
  spec.version       = "0.5.0"
  spec.authors       = ["iaintshine"]
  spec.email         = ["bodziomista@gmail.com"]

  spec.summary       = %q{Rack OpenTracing middleware enhanced for Rails}
  spec.description   = %q{}
  spec.homepage      = "https://github.com/iaintshine/ruby-rails-tracer"
  spec.license       = "Apache-2.0"

  spec.required_ruby_version = ">= 2.2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'opentracing', '~> 0.4'
  spec.add_dependency "rack-tracer", "~> 0.9.0"

  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "puma", "~> 3.7"
  spec.add_development_dependency "rspec-rails", "~> 3.6"
  spec.add_development_dependency "database_cleaner", "~> 1.6"
  spec.add_development_dependency "dalli", "~> 2.7.6"
  spec.add_development_dependency "tracing-logger", "~> 1.0"
  spec.add_development_dependency "test-tracer", "~> 1.0", ">= 1.2.1"
  spec.add_development_dependency "tracing-matchers", "~> 1.0", ">= 1.3.0"
  spec.add_development_dependency "spanmanager", "~> 0.3.0"
  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-console"
  spec.add_development_dependency "appraisal"
end
