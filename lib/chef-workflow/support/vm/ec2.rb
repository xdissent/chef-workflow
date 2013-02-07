require 'chef-workflow/support/debug'

module ChefWorkflow
  class VM
    class EC2Provisioner
      include ChefWorkflow::DebugSupport

      attr_accessor :name

      def initialize(name, number_of_servers)
        require 'chef-workflow/support/ec2'
        require 'chef-workflow/support/ip'
        require 'net/ssh'
        require 'timeout'

        @name = name
        @number_of_servers = number_of_servers
        init_instance_ids
      end

      def init_instance_ids
        @instance_ids = ChefWorkflow::DatabaseSupport::Set.new("vm_ec2_instances", name)
      end

      def ssh_connection_check(ip)
        Net::SSH.start(ip, ChefWorkflow::KnifeSupport.ssh_user, { :keys => [ChefWorkflow::KnifeSupport.ssh_identity_file] }) do |ssh|
          ssh.open_channel do |ch|
            ch.on_open_failed do
              return false
            end

            ch.exec("exit 0") do
              return true
            end
          end
          ssh.loop
        end
      rescue Exception => e
        return false
      end

      def ec2
        ChefWorkflow::EC2Support
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
          @instance_ids.add(instance.id)
        end

        ipaddress_mutex = Mutex.new
        debug_mutex = Mutex.new

        begin
          Timeout.timeout(ec2.provision_wait) do
            instances.map do |instance|
              Thread.new do
                loop do
                  ready = false

                  if instance.status == :running
                    ready = ssh_connection_check(instance.ip_address)
                    unless ready
                      if_debug(3) do
                        debug_mutex.synchronize do
                          $stderr.puts "Instance #{instance.id} running, but ssh isn't up yet."
                        end
                      end
                    end
                  else
                    if_debug(3) do
                      debug_mutex.synchronize do
                        $stderr.puts "#{instance.id} isn't running yet -- scheduling for re-check"
                      end
                    end
                  end

                  if ready
                    ipaddress_mutex.synchronize do
                      ip_addresses.push(instance.ip_address)
                    end
                    break
                  end

                  sleep 2
                end
              end
            end.each(&:join)
          end
        rescue TimeoutError
          raise "instances timed out waiting for ec2"
        end

        ip_addresses.each do |ipaddr|
          ChefWorkflow::IPSupport.assign_role_ip(name, ipaddr)
        end

        return ip_addresses
      end

      def shutdown
        aws_ec2 = ec2.ec2_obj

        @instance_ids.each do |instance_id|
          aws_ec2.instances[instance_id].terminate
        end

        @instance_ids.clear

        ChefWorkflow::IPSupport.delete_role(name)
        return true
      end

      def report
        init_instance_ids
        ["#{@number_of_servers} servers; instance ids: #{@instance_ids.to_a.join(" ")}"]
      end
    end
  end
end
