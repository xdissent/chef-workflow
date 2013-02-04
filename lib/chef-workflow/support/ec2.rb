require 'aws'
require 'chef-workflow/support/generic'
require 'chef-workflow/support/general'
require 'chef-workflow/support/debug'
require 'chef-workflow/support/attr'

module ChefWorkflow
  class EC2Support
    extend ChefWorkflow::AttrSupport
    include ChefWorkflow::DebugSupport

    fancy_attr :access_key_id
    fancy_attr :secret_access_key
    fancy_attr :ami
    fancy_attr :instance_type
    fancy_attr :region
    fancy_attr :ssh_key
    fancy_attr :security_groups
    fancy_attr :security_group_open_ports
    fancy_attr :provision_wait

    def initialize
      self.security_groups :auto
      self.security_group_open_ports [22, 4000]
      self.provision_wait 300
    end

    def ec2_obj
      args =
        if access_key_id and secret_access_key
          {
            :access_key_id => access_key_id,
            :secret_access_key => secret_access_key
          }
        else
          {
            :access_key_id => ENV["AWS_ACCESS_KEY_ID"],
            :secret_access_key => ENV["AWS_SECRET_ACCESS_KEY"]
          }
        end

      ec2 = AWS::EC2.new(args)
      ec2.regions[region]
    end

    #
    # Only used if security_groups is set to auto. Returns the filename to
    # marshal the automatically created security groups to.
    #
    def security_group_setting_path
      File.join(ChefWorkflow::GeneralSupport.workflow_dir, 'security-groups')
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

        break unless aws_ec2.security_groups[name].exists?
        sleep 0.3
      end

      group = aws_ec2.security_groups.create(name)

      security_group_open_ports.each do |port|
        group.authorize_ingress(:tcp, port)
        group.authorize_ingress(:udp, port)
      end

      group.authorize_ingress(:tcp, (0..65535), group)
      group.authorize_ingress(:udp, (0..65535), group)

      # XXX I think the name should be enough, but maybe this'll cause a problem.
      File.binwrite(security_group_setting_path, Marshal.dump([name]))
      return [name]
    end

    #
    # Loads any stored security groups. Returns nil if it can't.
    #
    def load_security_group
      Marshal.load(File.binread(security_group_setting_path)) rescue nil
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
        loaded_groups = load_security_group

        # this will make it hit the second block everytime from now on (and
        # bootstrap it recursively)
        if loaded_groups
          self.security_groups loaded_groups
          assert_security_groups
        else
          self.security_groups create_security_group
        end
      else
        self.security_groups = [security_groups] unless security_groups.kind_of?(Array)

        self.security_groups.each do |group|
          #
          # just retry this until it works -- some stupid flexible proxy in aws-sdk will bark about a missing method otherwise.
          #

          begin
            aws_ec2.security_groups[group]
          rescue
            sleep 1
            retry
          end

          raise "EC2 security group #{group} does not exist and it should." unless aws_ec2.security_groups[group]
        end
      end
    end

    def find_secgroup_running_instances(group_name)
      # exponential complexity with API calls? NO PROBLEM
      ec2_obj.instances.select do |i| 
        i.status != :terminated &&
          i.security_groups.find { |s| s.name == group_name }
      end
    end

    def destroy_security_group
      if File.exist?(security_group_setting_path)
        group_name = Marshal.load(File.binread(security_group_setting_path)).first

        until (instances = find_secgroup_running_instances(group_name)).empty?
          if_debug(1) do
            $stderr.puts "Trying to destroy security group #{group_name}, but instances are still bound to it."
            $stderr.puts instances.map(&:id).inspect
            $stderr.puts "Terminating instances, sleeping, and trying again."
          end

          instances.each do |i|
            i.terminate rescue nil
          end

          sleep 10
        end

        ec2_obj.security_groups.find { |g| g.name == group_name }.delete
      end
    end

    include ChefWorkflow::GenericSupport
  end
end

ChefWorkflow::EC2Support.configure
