require "chef-workflow/version"

require 'chef-workflow/support/general'
require 'chef-workflow/support/knife'
require 'chef-workflow/support/vagrant'
require 'chef-workflow/support/ip'
require 'chef-workflow/support/debug'
require 'chef-workflow/support/ec2'

if ENV["REFACTOR"]
  require 'deprecated'
  Deprecated.set_action(:raise)
end

module ChefWorkflow
  #
  # Basic helpers (intended to be mixed in elsewhere) to configure the
  # various support configuration systems.
  #
  module ConfigureHelper
    #
    # Configure 'GeneralSupport'
    #
    def configure_general(&block)
      ChefWorkflow::GeneralSupport.configure(&block)
    end

    #
    # Configure 'KnifeSupport'
    #
    def configure_knife(&block)
      ChefWorkflow::KnifeSupport.configure(&block)
    end

    #
    # Configure 'VagrantSupport'
    #
    def configure_vagrant(&block)
      ChefWorkflow::VagrantSupport.configure(&block)
    end

    #
    # Configure 'IPSupport' - you probably don't need to do this.
    #
    def configure_ips(&block)
      ChefWorkflow::IPSupport.configure(&block)
    end

    #
    # Configure 'EC2Support'
    #
    def configure_ec2(&block)
      ChefWorkflow::EC2Support.configure(&block)
    end
  end
end

class << eval("self", TOPLEVEL_BINDING)
  include ChefWorkflow::ConfigureHelper
end

if defined? Rake::DSL
  module Rake::DSL
    include ChefWorkflow::ConfigureHelper
  end
end

$:.unshift 'lib'

begin
  require 'chef-workflow-config'
rescue LoadError
  $stderr.puts "There is no chef-workflow-config in your lib directory."
  $stderr.puts "Please run chef-workflow-bootstrap or add one."
end
