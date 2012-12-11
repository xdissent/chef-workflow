require 'chef-workflow/support/knife'
require 'chef-workflow/support/knife-plugin'
require 'chef/knife/server_bootstrap_standalone'

class VM
  class ChefServerProvisioner
    include DebugSupport
    include KnifePluginSupport

    attr_accessor :name

    def startup(*args)
      ip = args.first.first.first # arg

      raise "No IP to use for the chef server" unless ip

      args = %W[--node-name test-chef-server --host #{ip}]

      args += %W[--ssh-user #{KnifeSupport.singleton.ssh_user}]                 if KnifeSupport.singleton.ssh_user
      args += %W[--ssh-password #{KnifeSupport.singleton.ssh_password}]         if KnifeSupport.singleton.ssh_password
      args += %W[--identity-file #{KnifeSupport.singleton.ssh_identity_file}]   if KnifeSupport.singleton.ssh_identity_file

      init_knife_plugin(Chef::Knife::ServerBootstrapStandalone, args).run
      true
    end

    def shutdown
      true
    end
  end
end
