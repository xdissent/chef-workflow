# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chef-workflow/version'

Gem::Specification.new do |gem|
  gem.name          = "chef-workflow"
  gem.version       = ChefWorkflow::VERSION
  gem.authors       = ["Erik Hollensbe"]
  gem.email         = ["erik+github@hollensbe.org"]
  gem.description   = %q{A comprehensive rake-based workflow for chef}
  gem.summary       = %q{A comprehensive rake-based workflow for chef}
  gem.homepage      = "https://github.com/chef-workflow/chef-workflow"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'vagrant-prison', '~> 0.1.0'
  gem.add_dependency 'chef', '~> 10.0'
  gem.add_dependency 'aws-sdk', '~> 1.7.0'
  gem.add_dependency 'net-ssh', '~> 2.2.2'
  gem.add_dependency 'knife-server', '~> 0.3.3'
  gem.add_dependency 'sqlite3', '~> 1.3.6'
  gem.add_dependency 'deprecated', '~> 3.0.1'

  gem.add_development_dependency 'rdoc'
  gem.add_development_dependency 'rake'
end
