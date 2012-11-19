require 'chef-workflow/support/debug'
require 'chef-workflow/support/vm'
require 'chef-workflow/support/knife'
require 'chef/node'
require 'chef/search/query'
require 'chef/application/knife'
require 'chef/knife/bootstrap'
require 'chef/knife/client_delete'
require 'chef/knife/node_delete'
require 'timeout'
require 'stringio'

class VM::KnifeProvisioner

  include DebugSupport
  
  attr_accessor :username
  attr_accessor :password
  attr_accessor :use_sudo
  attr_accessor :ssh_key
  attr_accessor :template_file
  attr_accessor :environment
  attr_accessor :port
  attr_accessor :ips
  attr_accessor :run_list
  attr_accessor :name

  def initialize
    @ips            = []
    @username       = nil
    @password       = nil
    @ssh_key        = nil
    @port           = nil
    @use_sudo       = nil
    @run_list       = nil
    @template_file  = nil
    @environment    = nil
    @node_names     = []
  end

  def startup(*args)
    @ips = args.first.first #argh
    raise "This provisioner is unnamed, cannot continue" unless name
    raise "This provisioner requires ip addresses which were not supplied" unless ips

    t = []
    ips.each_with_index do |ip, index|
      node_name = "#{name}-#{index}"
      @node_names.push(node_name)
      t.push bootstrap(node_name, ip)
    end

    t.each(&:join)

    return check_nodes
  end

  def shutdown
    t = []

    @node_names.each do |node_name|
      t.push(
        Thread.new do
          client_delete(node_name)
          node_delete(node_name)
        end
      )
    end

    t.each(&:join)
  end

  def check_nodes
    q = Chef::Search::Query.new
    unchecked_node_names = @node_names.dup

    # this dirty hack turns 'role[foo]' into 'roles:foo', but also works on
    # recipe[] too. Then joins the whole thing with AND
    search_query = run_list.
      map { |s| s.gsub(/\[/, 's:"').gsub(/\]/, '"') }.
      join(" AND ")

    Timeout.timeout(60) do
      until unchecked_node_names.empty?
        node_name = unchecked_node_names.shift
        if_debug(2) do
          $stderr.puts "Checking search validity for node #{node_name}"
        end

        result = q.search(
          :node, 
          search_query + %Q[ AND name:"#{node_name}"]
        ).first

        unless result and result.count == 1 and result.first.name == node_name
          unchecked_node_names << node_name
        end
        
        # unfortunately if this isn't here you might as well issue kill -9 to the
        # rake process
        sleep 0.3
      end
    end

    return true
  rescue Timeout::Error
    raise "Bootstrapped nodes for #{name} did not appear in Chef search index after 60 seconds."
  end

  def init_knife_plugin(klass, args)
    klass.options = Chef::Application::Knife.options.merge(klass.options)
    klass.load_deps
    cli = klass.new(args)
    cli.ui = Chef::Knife::UI.new(
      StringIO.new('', 'w'), 
      StringIO.new('', 'w'),
      StringIO.new('', 'r'),
      cli.config
    )
    cli.configure_chef

    return cli
  end

  def bootstrap(node_name, ip)
    args = []

    args += %W[-x #{username}]                    if username
    args += %W[-P #{password}]                    if password
    args += %w[--sudo]                            if use_sudo
    args += %W[-i #{ssh_key}]                     if ssh_key
    args += %W[--template-file #{template_file}]  if template_file
    args += %W[-p #{port}]                        if port 
    args += %W[-E #{environment}]                 if environment

    @run_list ||= ["role[#{name}]"]

    args += %W[-r '#{run_list.join(",")}']
    args += %W[-N '#{node_name}']
    args += [ip]

    bootstrap_cli = init_knife_plugin(Chef::Knife::Bootstrap, args)

    Thread.new do
      bootstrap_cli.run
      # knife bootstrap is the honey badger when it comes to exit status.
      # We can't rely on it, so we examine the run_list of the node instead
      # to ensure it converged.
      run_list_size = Chef::Node.load(node_name).run_list.to_a.size
      unless run_list_size > 0
        puts bootstrap_cli.ui.stdout.string
        puts bootstrap_cli.ui.stderr.string
        raise "bootstrap for #{node_name}/#{ip} wasn't successful."
      end
    end
  end

  def client_delete(node_name)
    init_knife_plugin(Chef::Knife::ClientDelete, [node_name, '-y']).run
  end

  def node_delete(node_name)
    init_knife_plugin(Chef::Knife::NodeDelete, [node_name, '-y']).run
  end
end
