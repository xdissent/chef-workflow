require 'chef-workflow/support/generic'
require 'chef-workflow/support/attr'

class GeneralSupport
  DEFAULT_CHEF_WORKFLOW_DIR = File.join(Dir.pwd, '.chef-workflow')
  DEFAULT_CHEF_VM_FILE = File.join(DEFAULT_CHEF_WORKFLOW_DIR, 'vms')

  extend AttrSupport 
  fancy_attr :workflow_dir
  fancy_attr :vm_file

  def initialize(workflow_dir=DEFAULT_CHEF_WORKFLOW_DIR, vm_file=DEFAULT_CHEF_VM_FILE)
    @workflow_dir = workflow_dir
    @vm_file = vm_file
  end

  include GenericSupport
end

GeneralSupport.configure
