require 'sqlite3'
require 'fileutils'
require 'delegate'
require 'singleton'
require 'chef-workflow/support/general'

module ChefWorkflow
  class DatabaseSupport < DelegateClass(SQLite3::Database)
    include Singleton

    def initialize
      super(connect)
    end

    def reconnect
      close rescue nil
      __setobj__(connect)
    end

    def connect
      vm_file = ChefWorkflow::GeneralSupport.vm_file
      FileUtils.mkdir_p(File.dirname(vm_file))
      SQLite3::Database.new(vm_file)
    end
  end
end
