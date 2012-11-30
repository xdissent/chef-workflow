require 'chef-workflwo/support/ec2'
require 'chef-workflow/support/ip'
require 'chef-workflow/support/vm'

class VM::EC2Provisioner

  attr_accessor :name

  def initialize(name, number_of_servers)
    @name = name
    @number_of_servers = number_of_servers
    @instance_ids = []
  end

  def ec2
    EC2Support.singleton
  end

  def ips
    IPSupport.singleton.get_role_ips(name)
  end

  def startup(*args)
    ec2.configure_aws
    aws_ec2 = AWS::EC2.new
  end

  def shutdown
    ec2.configure_aws
    aws_ec2 = AWS::EC2.new
    IPSupport.singleton.delete_role(name)
  end
end
