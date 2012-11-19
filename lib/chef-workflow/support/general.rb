require 'chef-workflow/support/generic'
require 'chef-workflow/support/attr'

class GeneralSupport
  DEFAULT_CHEF_WORKFLOW_DIR = File.join(Dir.pwd, '.chef-workflow')

  extend AttrSupport 
  fancy_attr :workflow_dir

  def initialize(workflow_dir=DEFAULT_CHEF_WORKFLOW_DIR)
    @workflow_dir = workflow_dir
  end

  include GenericSupport
end

GeneralSupport.configure
