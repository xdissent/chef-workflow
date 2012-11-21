require 'chef-workflow/support/vm'

class VM::VagrantProvisioner
  attr_reader :prison
  attr_reader :ips

  def initialize(prison, ips)
    @prison = prison
    @ips = ips
  end

  def ui_class
    $CHEF_WORKFLOW_DEBUG >= 2 ? Vagrant::UI::Basic : Vagrant::UI::Silent
  end

  def startup(*args)
    prison.construct(:ui_class => ui_class)
    return prison.start ? [ips] : false
  end

  def shutdown
    prison.configure_environment(:ui_class => ui_class)
    prison.cleanup
  end

  def name
    prison.name
  end

  def name=(name)
    prison.name = name
  end
end
