require 'chef-workflow/support/knife'
require 'chef-workflow/support/knife-plugin'
require 'chef/knife/server_bootstrap_standalone'

module ChefWorkflow
  class VM
    class ChefServerProvisioner
      include ChefWorkflow::DebugSupport
      include ChefWorkflow::KnifePluginSupport

      attr_accessor :name

      def startup(*args)
        ip = args.first.first #arg

        raise "No IP to use for the chef server" unless ip

        args = %W[--node-name test-chef-server --host #{ip}]

        args += %W[--ssh-user #{ChefWorkflow::KnifeSupport.singleton.ssh_user}]                 if ChefWorkflow::KnifeSupport.singleton.ssh_user
        args += %W[--ssh-password #{ChefWorkflow::KnifeSupport.singleton.ssh_password}]         if ChefWorkflow::KnifeSupport.singleton.ssh_password
        args += %W[--identity-file #{ChefWorkflow::KnifeSupport.singleton.ssh_identity_file}]   if ChefWorkflow::KnifeSupport.singleton.ssh_identity_file

        init_knife_plugin(Chef::Knife::ServerBootstrapStandalone, args).run
        true
      end

      def shutdown
        true
      end
    end
  end
end
