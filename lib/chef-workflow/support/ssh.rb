require 'chef-workflow/support/ip'
require 'chef-workflow/support/knife'
require 'chef-workflow/support/debug'
require 'net/ssh'

module ChefWorkflow
  #
  # Helper for performing SSH on groups of servers. Intended to be mixed into
  # test case classes.
  #
  module SSHHelper
    include ChefWorkflow::DebugSupport

    #
    # run a command against a group of servers. These commands are run in
    # parallel, but the command itself does not complete until all the threads
    # have finished running.
    #
    def ssh_role_command(role, command)
      t = []
      ChefWorkflow::IPSupport.get_role_ips(role).each do |ip|
        t.push(
          Thread.new do
            ssh_command(ip, command)
          end
        )
      end
      t.each(&:join)
    end

    #
    # takes a block which it uses inside of the open_channel block that Net::SSH
    # uses. Intended to provide a consistent way of setting up Net::SSH  Makes
    # heavy use of KnifeSupport to determine how to drive the command.
    #
    def configure_ssh_command(ip, command)
      command = "#{ChefWorkflow::KnifeSupport.use_sudo ? 'sudo ': ''}#{command}"

      options = { }

      options[:password] = ChefWorkflow::KnifeSupport.ssh_password          if ChefWorkflow::KnifeSupport.ssh_password
      options[:keys]     = [ChefWorkflow::KnifeSupport.ssh_identity_file]   if ChefWorkflow::KnifeSupport.ssh_identity_file

      Net::SSH.start(ip, ChefWorkflow::KnifeSupport.ssh_user, options) do |ssh|
        ssh.open_channel do |ch|
          ch.on_open_failed do |ch, code, desc|
            raise "Connection Error to #{ip}: #{desc}"
          end

          ch.exec(command) do |ch, success|
            yield ch, success
          end
        end

        ssh.loop
      end
    end

    #
    # Run a command against a single IP. Returns the exit status.
    # 
    #
    def ssh_command(ip, command)
      configure_ssh_command(ip, command) do |ch, success|
        return 1 unless success

        if_debug(2) do
          ch.on_data do |ch, data|
            $stderr.puts data
          end
        end

        ch.on_request("exit-status") do |ch, data|
          return data.read_long
        end
      end
    end

    #
    # run a command, and instead of capturing the exit status, return the data
    # captured during the command run.
    #
    def ssh_capture(ip, command)
      retval = ""
      configure_ssh_command(ip, command) do |ch, success|
        return "" unless success

        ch.on_data do |ch, data|
          retval << data
        end

        ch.on_request("exit-status") do |ch, data|
          return retval
        end
      end

      return retval
    end
  end
end
