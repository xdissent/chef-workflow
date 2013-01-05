require 'singleton'
require 'deprecated'
require 'chef-workflow/support/generic'
require 'chef-workflow/support/attr'

module ChefWorkflow
  #
  # General configuration, typically global to all chef-workflow related things.
  # See `GenericSupport` for a rundown of usage.
  #
  class GeneralSupport
    extend ChefWorkflow::AttrSupport 
    include Singleton

    class << self
      include Deprecated

      def singleton
        instance
      end

      def configure(&block)
        instance.instance_eval(&block) if block
      end

      def method_missing(sym, *args)
        instance.send(sym, *args)
      end

      deprecated :singleton, "ChefWorkflow::GeneralSupport class methods"
    end

    # Standard chef-workflow dir.
    DEFAULT_CHEF_WORKFLOW_DIR   = File.join(Dir.pwd, '.chef-workflow')
    # Location of the VM database.
    DEFAULT_CHEF_VM_FILE        = File.join(DEFAULT_CHEF_WORKFLOW_DIR, 'state.db')

    ##
    # :attr:
    # 
    # configure the workflow directory
    fancy_attr :workflow_dir

    ##
    # :attr:
    #
    # configure the location of the vm file
    fancy_attr :vm_file

    def initialize(opts={})
      @workflow_dir       = opts[:workflow_dir]       || DEFAULT_CHEF_WORKFLOW_DIR 
      @vm_file            = opts[:vm_file]            || DEFAULT_CHEF_VM_FILE
      machine_provisioner :vagrant
    end

    def machine_provisioner(*args)
      if args.count > 0
        @machine_provisioner = case args.first
                               when :ec2
                                 require 'chef-workflow/support/vm/ec2'
                                 ChefWorkflow::VM::EC2Provisioner
                               when :vagrant
                                 require 'chef-workflow/support/vm/vagrant'
                                 ChefWorkflow::VM::VagrantProvisioner
                               else
                                 args.first
                               end
      end

      @machine_provisioner
    end
  end
end

ChefWorkflow::GeneralSupport.configure
