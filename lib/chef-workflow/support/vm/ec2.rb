require 'chef-workflow/support/ec2'
require 'chef-workflow/support/ip'
require 'chef-workflow/support/debug'
require 'net/ssh'
require 'timeout'

module ChefWorkflow
  class VM
    class EC2Provisioner
      include ChefWorkflow::DebugSupport

      attr_accessor :name

      def initialize(name, number_of_servers)
        @name = name
        @number_of_servers = number_of_servers
        @instance_ids = []
      end

      def ssh_connection_check(ip)
        Net::SSH.start(ip, ChefWorkflow::KnifeSupport.singleton.ssh_user, { :keys => [ChefWorkflow::KnifeSupport.singleton.ssh_identity_file] }) do |ssh|
          ssh.open_channel do |ch|
            ch.on_open_failed do
              return false
            end

            ch.exec("exit 0") do
              return true
            end
          end
        end
      rescue
        return false
      end

      def ec2
        ChefWorkflow::EC2Support.singleton
      end

      def startup(*args)
        aws_ec2 = ec2.ec2_obj

        ec2.assert_security_groups

        instances = aws_ec2.instances.create(
          :count            => @number_of_servers,
          :image_id         => ec2.ami,
          :security_groups  => ec2.security_groups,
          :key_name         => ec2.ssh_key,
          :instance_type    => ec2.instance_type
        )

        #
        # instances isn't actually an array above -- see this url:
        #
        # https://github.com/aws/aws-sdk-ruby/issues/100
        #
        # Actually make it a real array here so it's useful.
        #

        if instances.kind_of?(Array)
          new_instances = []

          instances.each do |instance|
            new_instances.push(instance)
          end

          instances = new_instances
        else
          instances = [instances]
        end

        #
        # There are instances where AWS won't acknowledge a created instance
        # right away. Let's make sure the API server knows they all exist before
        # moving forward.
        #

        unresolved_instances = instances.dup

        until unresolved_instances.empty?
          instance = unresolved_instances.shift

          unless (instance.status rescue nil)
            if_debug(3) do
              $stderr.puts "API server doesn't think #{instance.id} exists yet."
            end

            sleep 0.3
            unresolved_instances.push(instance)
          end
        end

        ip_addresses = []
        
        instances.each do |instance|
          @instance_ids.push(instance.id)
        end

        begin
          Timeout.timeout(ec2.provision_wait) do
            until instances.empty?
              instance = instances.shift

              ready = false

              if instance.status == :running
                ready = ssh_connection_check(instance.ip_address)
                unless ready
                  if_debug(3) do
                    $stderr.puts "Instance #{instance.id} running, but ssh isn't up yet."
                  end
                end
              else
                if_debug(3) do
                  $stderr.puts "#{instance.id} isn't running yet -- scheduling for re-check"
                end
              end

              if ready
                ip_addresses.push(instance.ip_address)
                ChefWorkflow::IPSupport.singleton.assign_role_ip(name, instance.ip_address)
              else
                sleep 0.3
                instances.push(instance)
              end
            end
          end
        rescue TimeoutError
          raise "instances timed out waiting for ec2"
        end

        return ip_addresses
      end

      def shutdown
        aws_ec2 = ec2.ec2_obj

        @instance_ids.each do |instance_id|
          aws_ec2.instances[instance_id].terminate
        end

        ChefWorkflow::IPSupport.singleton.delete_role(name)
        return true
      end
    end

    def report
      ["#{@number_of_servers} servers; instance ids: #{@instance_ids.join(" ")}"]
    end
  end
end
