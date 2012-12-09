require 'chef-workflow/support/ec2'
require 'chef-workflow/support/ip'

class VM
  class EC2Provisioner
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
      aws_ec2 = ec2.ec2_obj
    end

    def shutdown
      aws_ec2 = ec2.ec2_obj
      IPSupport.singleton.delete_role(name)
    end
  end
end
