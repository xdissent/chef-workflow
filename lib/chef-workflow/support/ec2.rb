require 'aws'
require 'chef-workflow/support/debug'
require 'chef-workflow/support/knife'
require 'chef-workflow/support/generic'
require 'chef-workflow/support/attr'

class EC2Support
  extend AttrSupport
  include DebugSupport

  fancy_attr :access_key_id
  fancy_attr :secret_access_key
  fancy_attr :ami
  fancy_attr :instance_type
  fancy_attr :region
  fancy_attr :ssh_key
  fancy_attr :security_groups
  fancy_attr :security_group_open_ports

  def initialize
    self.security_groups :auto
    self.security_group_open_ports [22, 4000]
  end

  def ec2_obj
    ec2 = AWS::EC2.new(
      :access_key_id => ec2.access_key_id,
      :secret_access_key => ec2.secret_access_key
    )

    ec2.regions[region]
  end

  #
  # Only used if security_groups is set to auto. Returns the filename to
  # marshal the automatically created security groups to.
  #
  def security_group_setting_path
    File.join(GeneralSupport.singleton.workflow_dir, 'security-groups')
  end

  #
  # Creates a security group and saves it to the security_group_setting_path.
  #
  def create_security_group
    aws_ec2 = ec2_obj

    name = nil

    loop do
      name = 'chef-workflow-' + (0..rand(10).to_i).map { rand(0..9).to_s }.join("")

      if_debug(3) do
        $stderr.puts "Seeing if security group name #{name} is taken"
      end

      break unless aws_ec2.security_groups[name]
    end

    group = aws_ec2.security_groups.create(name)

    security_group_open_ports.each do |port|
      group.authorize_ingress(:tcp, port)
      group.authorize_ingress(:udp, port)
    end

    # XXX I think the name should be enough, but maybe this'll cause a problem.
    File.binwrite(security_group_setting_path, Marshal.dump([name]))
  end

  #
  # Ensures security groups exist.
  #
  # If @security_groups is :auto, creates one and sets it up with the
  # security_group_open_ports on TCP and UDP.
  #
  # If @security_groups is an array of group names or a single group name,
  # asserts they exist. If they do not exist, it raises.
  #
  def assert_security_groups
    aws_ec2 = ec2_obj

    if security_groups == :auto
      loaded_groups = Marshal.load(File.binread(security_group_setting_path)) rescue nil


      # this will make it hit the second block everytime from now on (and
      # bootstrap it recursively)
      if loaded_groups
        self.security_groups loaded_groups
        assert_security_groups
      else
        create_security_group
      end
    else
      self.security_groups = [security_groups] unless security_groups.kind_of?(Array)

      self.security_groups.each do |group|
        raise "EC2 security group #{group} does not exist and it should." unless aws_ec2.security_groups[group]
      end
    end
  end

  include GenericSupport
end

EC2Support.configure
