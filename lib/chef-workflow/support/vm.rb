require 'set'
require 'fileutils'
require 'chef-workflow/support/general'
require 'chef-workflow/support/attr'
require 'chef-workflow/support/debug'
require 'chef-workflow/support/db/group'

#--
# XXX see the dynamic require at the bottom
#++

module ChefWorkflow
  #
  # This class mainly exists to track the run state of the Scheduler, and is kept
  # simple so that the contents can be marshalled and restored from a file.
  #
  class VM
    class << self
      extend ChefWorkflow::AttrSupport
      fancy_attr :vm_file
    end

    include ChefWorkflow::DebugSupport
    extend ChefWorkflow::AttrSupport

    #
    # If a file exists that contains a VM object, load it. Use VM.vm_file to
    # control the location of this file.
    #
    def self.load_from_file
      vm_file = ChefWorkflow::GeneralSupport.singleton.vm_file

      if File.file?(vm_file)
        obj = Marshal.load(File.binread(vm_file))
        obj.groups = ChefWorkflow::DatabaseSupport::VMGroup.new
      end

      return nil
    end
  
    #
    # Save the marshalled representation to a file. Use VM.vm_file to control the
    # location of this file.
    #
    def save_to_file
      vm_file = ChefWorkflow::GeneralSupport.singleton.vm_file
      groups = self.groups
      self.groups = nil
      marshalled = Marshal.dump(self)
      FileUtils.mkdir_p(File.dirname(vm_file))
      res = File.binwrite(vm_file, marshalled)
      self.groups = groups
      return res
    end

    # the vm groups and their provisioning lists.
    attr_accessor :groups
    # the dependencies that each vm group depends on
    attr_reader :dependencies
    # the set of provisioned (solved) groups
    attr_reader :provisioned
    # the set of provisioning (working) groups
    attr_reader :working

    def clean
      @groups        = ChefWorkflow::DatabaseSupport::VMGroup.new(true)
      @dependencies  = { }
      @provisioned   = Set.new
      @working       = Set.new
    end

    def initialize
      @groups        = ChefWorkflow::DatabaseSupport::VMGroup.new
      @dependencies  = { }
      @provisioned   = Set.new
      @working       = Set.new
    end
  end

  # XXX require all the provisioners -- marshal will blow up unless this is done.
  Dir[File.join(File.expand_path(File.dirname(__FILE__)), 'vm', '*')].each do |x|
    require x if File.file?(x)
  end
end
