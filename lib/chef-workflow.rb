require "chef-workflow/version"

require 'chef-workflow/support/general'
require 'chef-workflow/support/knife'
require 'chef-workflow/support/vagrant'
require 'chef-workflow/support/ip'
require 'chef-workflow/support/debug'

$:.unshift 'lib'

begin
  require 'chef-workflow-config'
rescue LoadError
  $stderr.puts "There is no chef-workflow-config in your lib directory."
  $stderr.puts "Please run chef-workflow-bootstrap or add one."
end

class Chef
  module Workflow
    #
    # Basic helpers (intended to be mixed in elsewhere) to configure the
    # various support configuration systems.
    #
    module ConfigureHelper
      #
      # Configure 'GeneralSupport'
      #
      def configure_general(&block)
        GeneralSupport.configure(&block)
      end

      #
      # Configure 'KnifeSupport'
      #
      def configure_knife(&block)
        KnifeSupport.configure(&block)
      end

      #
      # Configure 'VagrantSupport'
      #
      def configure_vagrant(&block)
        VagrantSupport.configure(&block)
      end
      
      #
      # Configure 'IPSupport' - you probably don't need to do this.
      #
      def configure_ips(&block)
        IPSupport.configure(&block)
      end
    end
  end
end

class << eval("self", TOPLEVEL_BINDING)
  include Chef::Workflow::ConfigureHelper
end

if defined? Rake::DSL
  module Rake::DSL
    include Chef::Workflow::ConfigureHelper
  end
end
