require 'chef-workflow/support/vm'

class VM::VagrantProvisioner
  attr_reader :prison
  attr_reader :ips

  def initialize(prison, ips)
    @prison = prison
    @ips = ips
  end

  def startup(*args)
    prison.construct
    return prison.start ? [ips] : false
  end

  def shutdown
    prison.cleanup
  end

  def name
    prison.name
  end

  def name=(name)
    prison.name = name
  end
end
