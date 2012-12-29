require 'sqlite3'
require 'fileutils'
require 'delegate'
require 'singleton'
require 'chef-workflow/support/general'

module ChefWorkflow
  class DatabaseSupport < DelegateClass(SQLite3::Database)
    include Singleton

    def initialize
      workflow_dir = ChefWorkflow::GeneralSupport.singleton.workflow_dir
      dbpath = File.join(workflow_dir, "state.db")
      FileUtils.mkdir_p(workflow_dir)
      @db = SQLite3::Database.new(dbpath)
      super(@db)
    end
  end
end
