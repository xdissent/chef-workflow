require 'chef-workflow/support/generic'
require 'chef-workflow/support/attr'
require 'chef-workflow/support/vm/vagrant'
require 'chef-workflow/support/vm/ec2'

#
# General configuration, typically global to all chef-workflow related things.
# See `GenericSupport` for a rundown of usage.
#
class GeneralSupport
  # Standard chef-workflow dir.
  DEFAULT_CHEF_WORKFLOW_DIR   = File.join(Dir.pwd, '.chef-workflow')
  # Location of the VM database.
  DEFAULT_CHEF_VM_FILE        = File.join(DEFAULT_CHEF_WORKFLOW_DIR, 'vms')
  # Location of the chef-server prison file (vagrant only).
  DEFAULT_CHEF_SERVER_PRISON  = File.join(DEFAULT_CHEF_WORKFLOW_DIR, 'chef-server')

  extend AttrSupport 

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

  ##
  # :attr:
  #
  # configure the location of the chef server prison.
  fancy_attr :chef_server_prison

  def initialize(opts={})
    @workflow_dir       = opts[:workflow_dir]       || DEFAULT_CHEF_WORKFLOW_DIR 
    @vm_file            = opts[:vm_file]            || DEFAULT_CHEF_VM_FILE
    @chef_server_prison = opts[:chef_server_prison] || DEFAULT_CHEF_SERVER_PRISON
    machine_provisioner :vagrant
  end

  def machine_provisioner(*args)
    if args.count > 0
      @machine_provisioner = case args.first
                             when :ec2
                               VM::EC2Provisioner
                             when :vagrant
                               VM::VagrantProvisioner
                             else
                               args.first
                             end
    end

    @machine_provisioner
  end

  include GenericSupport
end

GeneralSupport.configure
