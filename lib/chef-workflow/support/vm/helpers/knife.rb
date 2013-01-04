require 'chef-workflow/support/vm/knife'

module ChefWorkflow
  module KnifeProvisionHelper
    def build_knife_provisioner 
      kp              = ChefWorkflow::VM::KnifeProvisioner.new
      kp.username     = ChefWorkflow::KnifeSupport.ssh_user
      kp.password     = ChefWorkflow::KnifeSupport.ssh_password
      kp.use_sudo     = ChefWorkflow::KnifeSupport.use_sudo
      kp.ssh_key      = ChefWorkflow::KnifeSupport.ssh_identity_file
      kp.environment  = ChefWorkflow::KnifeSupport.test_environment

      return kp
    end
  end
end

if defined? Rake::DSL
  module Rake::DSL
    include ChefWorkflow::KnifeProvisionHelper
  end
end

class << eval('self', TOPLEVEL_BINDING)
  include ChefWorkflow::KnifeProvisionHelper
end
