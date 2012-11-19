require "chef-workflow/version"

require 'chef-workflow/support/general'
require 'chef-workflow/support/knife'
require 'chef-workflow/support/vagrant'
require 'chef-workflow/support/ip'
require 'chef-workflow/support/debug'

class Chef
  module Workflow
    module ConfigureHelper
      def configure_general(&block)
        GeneralSupport.configure(&block)
      end

      def configure_knife(&block)
        KnifeSupport.configure(&block)
      end

      def configure_vagrant(&block)
        VagrantSupport.configure(&block)
      end

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
