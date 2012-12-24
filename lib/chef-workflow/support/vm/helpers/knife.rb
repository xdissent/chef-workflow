require 'chef-workflow/support/vm/knife'

module KnifeProvisionHelper
  def build_knife_provisioner 
    kp              = VM::KnifeProvisioner.new
    kp.username     = KnifeSupport.singleton.ssh_user
    kp.password     = KnifeSupport.singleton.ssh_password
    kp.use_sudo     = KnifeSupport.singleton.use_sudo
    kp.ssh_key      = KnifeSupport.singleton.ssh_identity_file
    kp.environment  = KnifeSupport.singleton.test_environment

    return kp
  end
end

if defined? Rake::DSL
  module Rake::DSL
    include KnifeProvisionHelper
  end
end

class << eval('self', TOPLEVEL_BINDING)
  include KnifeProvisionHelper
end
