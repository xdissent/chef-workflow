require 'chef-workflow/support/generic'
require 'chef-workflow/support/attr'

class GeneralSupport
  DEFAULT_CHEF_WORKFLOW_DIR   = File.join(Dir.pwd, '.chef-workflow')
  DEFAULT_CHEF_VM_FILE        = File.join(DEFAULT_CHEF_WORKFLOW_DIR, 'vms')
  DEFAULT_CHEF_SERVER_PRISON  = File.join(DEFAULT_CHEF_WORKFLOW_DIR, 'chef-server')

  extend AttrSupport 

  fancy_attr :workflow_dir
  fancy_attr :vm_file
  fancy_attr :chef_server_prison

  def initialize(opts={})
    @workflow_dir       = opts[:workflow_dir]       || DEFAULT_CHEF_WORKFLOW_DIR 
    @vm_file            = opts[:vm_file]            || DEFAULT_CHEF_VM_FILE
    @chef_server_prison = opts[:chef_server_prison] || DEFAULT_CHEF_SERVER_PRISON
  end

  include GenericSupport
end

GeneralSupport.configure
