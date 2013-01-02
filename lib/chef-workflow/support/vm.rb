require 'set'
require 'fileutils'
require 'chef-workflow/support/general'
require 'chef-workflow/support/attr'
require 'chef-workflow/support/debug'
require 'chef-workflow/support/db/group'
require 'chef-workflow/support/db/basic'

#--
# XXX see the dynamic require at the bottom
#++

module ChefWorkflow
  #
  # This class mainly exists to track the run state of the Scheduler, and is kept
  # simple so that the contents can be marshalled and restored from a file.
  #
  class VM
    include ChefWorkflow::DebugSupport

    # the vm groups and their provisioning lists.
    attr_reader :groups
    # the dependencies that each vm group depends on
    attr_reader :dependencies
    # the set of provisioned (solved) groups
    attr_reader :provisioned
    # the set of provisioning (working) groups
    attr_reader :working

    def initialize
      @groups        = ChefWorkflow::DatabaseSupport::VMGroup.new('vm_groups', false)
      @dependencies  = ChefWorkflow::DatabaseSupport::VMGroup.new('vm_dependencies', true)
      @provisioned   = ChefWorkflow::DatabaseSupport::Set.new('vm_scheduler', 'provisioned')
      @working       = ChefWorkflow::DatabaseSupport::Set.new('vm_scheduler', 'working')
    end
  end

  # XXX require all the provisioners -- marshal will blow up unless this is done.
  Dir[File.join(File.expand_path(File.dirname(__FILE__)), 'vm', '*')].each do |x|
    require x if File.file?(x)
  end
end
