require 'chef-workflow/support/debug'
require 'chef-workflow/support/knife-plugin'

module ChefWorkflow
  class VM
    class ChefServerProvisioner
      include ChefWorkflow::DebugSupport
      include ChefWorkflow::KnifePluginSupport

      attr_accessor :name

      def startup(*args)
        require 'chef-workflow/support/knife'
        require 'chef/knife/ssh' # required for chef 10.12
        require 'chef/knife/server_bootstrap_standalone'

        ip = args.first.first #arg

        raise "No IP to use for the chef server" unless ip

        args = %W[--node-name test-chef-server --host #{ip}]

        args += %W[--ssh-user #{ChefWorkflow::KnifeSupport.ssh_user}]                 if ChefWorkflow::KnifeSupport.ssh_user
        args += %W[--ssh-password #{ChefWorkflow::KnifeSupport.ssh_password}]         if ChefWorkflow::KnifeSupport.ssh_password
        args += %W[--identity-file #{ChefWorkflow::KnifeSupport.ssh_identity_file}]   if ChefWorkflow::KnifeSupport.ssh_identity_file
        args += %W[--webui-password #{ChefWorkflow::KnifeSupport.webui_password}]     if ChefWorkflow::KnifeSupport.webui_password

        init_knife_plugin(Chef::Knife::ServerBootstrapStandalone, args).run
        true
      end

      def shutdown
        true
      end

      def report
        [name]
      end
    end
  end
end
