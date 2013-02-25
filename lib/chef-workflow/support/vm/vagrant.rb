require 'vagrant/prison'

module ChefWorkflow
  class VM
    #
    # Provisions a server group with vagrant and virtualbox.
    #
    # All vagrant machines share the same IP address on eth0, which is typically
    # 10.0.2.15. To compensate for that, a host-only network address will be
    # auto-generated for each server in the group and lives on eth1. It is strongly
    # recommended that you deal with this problem in your chef cookbooks, as
    # node["ipaddress"] will typically be wrong and we cannot compensate for it.
    #
    # Groups provisioned in this manner are done so with Vagrant::Prison.
    #
    class VagrantProvisioner
      require 'chef-workflow/support/vagrant'
      require 'chef-workflow/support/ip'
      require 'chef-workflow/support/db/basic'

      # Vagrant::Prison object
      attr_reader :prison
      # number of servers to provision
      attr_reader :number_of_servers
      # name of server group
      attr_accessor :name

      #
      # Constructor. Expects a server group name and a number of servers to provision.
      #
      def initialize(name, number_of_servers)
        @db                 = ChefWorkflow::DatabaseSupport::Object.new("vm_prisons")
        @name               = name
        @number_of_servers  = number_of_servers
        @prison             = @db[name]
      end

      #
      # Get the ips associated with this server group.
      #
      def ips
        ChefWorkflow::IPSupport.get_role_ips(name)
      end

      #
      # Get the appropriate Vagrant UI class, depending on debugging settings.
      #
      def ui_class
        $CHEF_WORKFLOW_DEBUG >= 2 ? Vagrant::UI::Basic : Vagrant::UI::Silent
      end

      #
      # helper to bootstrap vagrant requirements.
      #
      def bootstrap_vagrant_ipsupport
        ChefWorkflow::IPSupport.seed_vagrant_ips
      end

      #
      # Provision a group of servers. If successful, returns an array of the ips
      # allocated for the group. Ignores incoming arguments.
      #
      def startup(*args)
        bootstrap_vagrant_ipsupport

        ChefWorkflow::IPSupport.delete_role(name)

        @prison = Vagrant::Prison.new(Dir.mktmpdir, false)
        prison.name = name
        prison.configure do |config|
          config.vm.box_url = ChefWorkflow::VagrantSupport.box_url
          config.vm.box = ChefWorkflow::VagrantSupport.box
          ChefWorkflow::VagrantSupport.customizations.each { |c| config.vm.customize c }
          number_of_servers.times do |x|
            ip = ChefWorkflow::IPSupport.unused_ip
            ChefWorkflow::IPSupport.assign_role_ip(name, ip)
            config.vm.define "#{name}-#{x}" do |this_config|
              this_config.vm.network :hostonly, ip
            end
          end
        end

        prison.construct(:ui_class => ui_class)
        @db[name] = prison # eager save in case start has issues

        return prison.start ? ips : false
      ensure
        @db[name] = prison
      end

      #
      # Deprovisions the servers for this group, and cleans up the prison and
      # allocated IP addresses.
      #
      def shutdown
        @prison ||= @db[name]

        if prison
          prison.configure_environment(:ui_class => ui_class)
          prison.cleanup
        end
        ChefWorkflow::IPSupport.delete_role(name)
        @db.delete(name)
        return true
      end

      def report
        ["#{@number_of_servers} servers; prison dir: #{@prison.dir}"]
      end
    end
  end
end
