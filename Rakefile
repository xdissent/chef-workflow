require "bundler/gem_tasks"
require 'rdoc/task'

RDoc::Task.new do |r|
  r.main = "README.md"
  r.rdoc_files.include("README.md", "LICENSE.txt", "lib/**/*.rb")
  r.options << "--all"
end
