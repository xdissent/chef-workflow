require 'chef-workflow/support/vm'

class VM::VagrantProvisioner
  attr_reader :prison

  def initialize(prison)
    @prison = prison
  end

  def startup
    prison.construct
    prison.start
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
