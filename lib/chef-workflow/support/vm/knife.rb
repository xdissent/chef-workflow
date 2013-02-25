require 'chef-workflow/support/debug'
require 'chef-workflow/support/knife-plugin'

module ChefWorkflow
  class VM
    #
    # The Knife Provisioner does three major things:
    #
    # * Bootstraps a series of machines living on IP addresses supplied to it
    # * Ensures that they converged successfully (if not, raises and displays output)
    # * Waits until chef has indexed their metadata
    #
    # On deprovision, it deletes the nodes and clients related to this server group.
    #
    # Machines are named as such: $server_group-$number, where $number starts at 0
    # and increases with the number of servers requested. Your node names will be
    # named this as well as the clients associated with them.
    #
    # It does as much of this as it can in parallel, but stalls the current thread
    # until the subthreads complete. This allows is to work as quickly as possible
    # in a 'serial' scheduling scenario as we know bootstrapping can always occur
    # in parallel for the group.
    #
    class KnifeProvisioner

      include ChefWorkflow::DebugSupport
      include ChefWorkflow::KnifePluginSupport

      # the username for SSH.
      attr_accessor :username
      # the password for SSH.
      attr_accessor :password
      # drive knife bootstrap's sudo functionality.
      attr_accessor :use_sudo
      # the ssh key to be used for SSH
      attr_accessor :ssh_key
      # the bootstrap template to be used.
      attr_accessor :template_file
      # the chef environment to be used.
      attr_accessor :environment
      # the port to contact for SSH
      attr_accessor :port
      # the list of IPs to provision.
      attr_accessor :ips
      # the run list of this server group.
      attr_accessor :run_list
      # the name of this server group.
      attr_accessor :name
      # perform the solr check to ensure the instance has converged and its
      # metadata is ready for searching.
      attr_accessor :solr_check
      # distro
      attr_accessor :distro
      # host key verify
      attr_accessor :host_key_verify

      # constructor.
      def initialize
        require 'chef/node'
        require 'chef/search/query'
        require 'chef/knife/ssh'
        require 'chef/knife/bootstrap'
        require 'chef-workflow/support/knife'
        require 'timeout'

        @ips            = []
        @username       = nil
        @password       = nil
        @ssh_key        = nil
        @port           = nil
        @use_sudo       = nil
        @run_list       = nil
        @template_file  = nil
        @environment    = nil
        @solr_check     = true
        @distro         = nil
        @host_key_verify = true
      end

      def init_nodes_db
        @node_names = ChefWorkflow::DatabaseSupport::Set.new('nodes', name)
      end

      #
      # Runs the provisioner. Accepts an array of IP addresses as its first
      # argument, intended to be provided by provisioners that ran before it as
      # their return value.
      #
      # Will raise if the IPs are not supplied or the provisioner is not named with
      # a server group.
      #
      def startup(*args)
        @ips = args.first #argh
        raise "This provisioner is unnamed, cannot continue" unless name
        raise "This provisioner requires ip addresses which were not supplied" unless ips

        init_nodes_db

        @run_list ||= ["role[#{name}]"]

        t = []
        ips.each_with_index do |ip, index|
          node_name = "#{name}-#{index}"
          @node_names.add(node_name)
          t.push bootstrap(node_name, ip)
        end

        t.each(&:join)

        return solr_check ? check_nodes : true
      end

      #
      # Deprovisions the server group. Runs node delete and client delete on all
      # nodes that were created by this provisioner.
      #
      def shutdown
        t = []

        init_nodes_db

        @node_names.each do |node_name|
          t.push(
            Thread.new do
              client_delete(node_name) rescue nil
              node_delete(node_name) rescue nil
            end
          )
        end

        t.each(&:join)

        @node_names.clear

        return true
      end

      #
      # Checks that the nodes have made it into the search index. Will block until
      # all nodes in this server group are found, or a 60 second timeout is
      # reached, at which point it will raise.
      #
      def check_nodes
        q = Chef::Search::Query.new
        unchecked_node_names = @node_names.to_a

        # this dirty hack turns 'role[foo]' into 'roles:foo', but also works on
        # recipe[] too. Then joins the whole thing with AND
        search_query = run_list.
          map { |s| s.gsub(/\[/, 's:"').gsub(/\]/, '"') }.
          join(" AND ")

        Timeout.timeout(ChefWorkflow::KnifeSupport.search_index_wait) do
          until unchecked_node_names.empty?
            node_name = unchecked_node_names.shift
            if_debug(3) do
              $stderr.puts "Checking search validity for node #{node_name}"
            end

            result = q.search(
              :node,
              search_query + %Q[ AND name:"#{node_name}"]
            ).first

            unless result and result.count == 1 and result.first.name == node_name
              unchecked_node_names << node_name
            end

            # unfortunately if this isn't here you might as well issue kill -9 to
            # the rake process
            sleep 0.3
          end
        end

        return true
      rescue Timeout::Error
        raise "Bootstrapped nodes for #{name} did not appear in Chef search index after 60 seconds."
      end

      #
      # Bootstraps a single node. Validates bootstrap by checking the node metadata
      # directly and ensuring it made it into the chef server.
      #
      def bootstrap(node_name, ip)
        args = []

        args += %W[-x #{username}]                    if username
        args += %W[-P #{password}]                    if password
        args += %w[--sudo]                            if use_sudo
        args += %W[-i #{ssh_key}]                     if ssh_key
        args += %W[--template-file #{template_file}]  if template_file
        args += %W[-p #{port}]                        if port
        args += %W[-E #{environment}]                 if environment
        args += %W[--#{"no-" unless host_key_verify}host-key-verify]

        args += %W[-d #{distro || "chef-full"}]
        args += %W[-r #{run_list.join(",")}]
        args += %W[-N '#{node_name}']
        args += [ip]

        bootstrap_cli = init_knife_plugin(Chef::Knife::Bootstrap, args)

        Thread.new do
          begin
            bootstrap_cli.run
          rescue SystemExit => e
            # welp, looks like they finally fixed it.
            # can't rely on it for compat reasons, but at least we're not
            # dropping to a prompt when a bootstrap fails.
          end
          # knife bootstrap is the honey badger when it comes to exit status.
          # We can't rely on it, so we examine the run_list of the node instead
          # to ensure it converged.
          run_list_size = Chef::Node.load(node_name).run_list.to_a.size rescue 0
          unless run_list_size > 0
            puts bootstrap_cli.ui.stdout.string
            puts bootstrap_cli.ui.stderr.string
            raise "bootstrap for #{node_name}/#{ip} wasn't successful."
          end
          if_debug(2) do
            puts bootstrap_cli.ui.stdout.string
            puts bootstrap_cli.ui.stderr.string
          end
        end
      end

      #
      # Deletes a chef client.
      #
      def client_delete(node_name)
        require 'chef/knife/client_delete'
        init_knife_plugin(Chef::Knife::ClientDelete, [node_name, '-y']).run
      end

      #
      # Deletes a chef node.
      #
      def node_delete(node_name)
        require 'chef/knife/node_delete'
        init_knife_plugin(Chef::Knife::NodeDelete, [node_name, '-y']).run
      end

      def report
        res = ["nodes:"]

        ChefWorkflow::IPSupport.get_role_ips(name).each_with_index do |ip, i|
          res += ["#{name}-#{i}: #{ip}"]
        end

        return res
      end
    end
  end
end
