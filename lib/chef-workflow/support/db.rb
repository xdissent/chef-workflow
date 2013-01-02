require 'sqlite3'
require 'fileutils'
require 'delegate'
require 'singleton'
require 'chef-workflow/support/general'

module ChefWorkflow
  class DatabaseSupport < DelegateClass(SQLite3::Database)
    include Singleton

    def initialize
      vm_file = ChefWorkflow::GeneralSupport.singleton.vm_file
      FileUtils.mkdir_p(File.dirname(vm_file))
      @db = SQLite3::Database.new(vm_file)
      super(@db)
    end
  end
end
