# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chef-workflow/version'

Gem::Specification.new do |gem|
  gem.name          = "chef-workflow"
  gem.version       = Chef::Workflow::VERSION
  gem.authors       = ["Erik Hollensbe"]
  gem.email         = ["erik+github@hollensbe.org"]
  gem.description   = %q{A comprehensive rake-based workflow for chef}
  gem.summary       = %q{A comprehensive rake-based workflow for chef}
  gem.homepage      = "https://github.com/hoteltonight/chef-workflow"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'vagrant-prison'
  gem.add_dependency 'chef'

  gem.add_development_dependency 'rdoc'
  gem.add_development_dependency 'rake'
end
