require "chef-workflow/version"

require 'chef-workflow/knife-support'
require 'chef-workflow/vagrant-support'
require 'chef-workflow/ip-support'
require 'chef-workflow/debug-support'

class Chef
  module Workflow
    module ConfigureHelper
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
