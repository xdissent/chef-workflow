require 'chef-workflow/support/vagrant'
require 'chef-workflow/support/ip'
require 'chef-workflow/support/vm'
require 'vagrant/prison'

class VM::VagrantProvisioner
  attr_reader :prison
  attr_reader :number_of_servers
  attr_accessor :name

  def initialize(name, number_of_servers)
    @prison             = nil
    @name               = name
    @number_of_servers  = number_of_servers
  end

  def ips
    IPSupport.singleton.get_role_ips(name)
  end

  def ui_class
    $CHEF_WORKFLOW_DEBUG >= 2 ? Vagrant::UI::Basic : Vagrant::UI::Silent
  end

  def startup(*args)
    IPSupport.singleton.delete_role(name)

    @prison = Vagrant::Prison.new(Dir.mktmpdir, false)
    prison.name = name
    prison.configure do |config|
      config.vm.box_url = VagrantSupport.singleton.box_url
      config.vm.box = VagrantSupport.singleton.box
      number_of_servers.times do |x|
        ip = IPSupport.singleton.unused_ip
        IPSupport.singleton.assign_role_ip(name, ip)
        config.vm.define "#{name}-#{x}" do |this_config|
          this_config.vm.network :hostonly, ip
        end
      end
    end

    prison.construct(:ui_class => ui_class)

    return prison.start ? [ips] : false
  end

  def shutdown
    prison.configure_environment(:ui_class => ui_class)
    prison.cleanup
    IPSupport.singleton.delete_role(name)
  end
end
