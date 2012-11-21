require 'delegate'
require 'fileutils'
require 'chef-workflow/support/generic'
require 'chef-workflow/support/attr'

ENV["TEST_CHEF_SUBNET"] ||= "10.10.10.0"

#
# IP allocation database. Uses `GenericSupport`.
#
class IPSupport < DelegateClass(Hash)
  extend AttrSupport

  ##
  # :attr:
  #
  # The subnet used for calculating assignable IP addresses. You really want to
  # set `TEST_CHEF_SUBNET` in your environment instead of changing this.
  #
  fancy_attr :subnet

  ##
  # :attr:
  #
  # The location of the ip database.
  #
  fancy_attr :ip_file

  def initialize(subnet=ENV["TEST_CHEF_SUBNET"], ip_file=File.join(Dir.pwd, '.chef-workflow', 'ips'))
    @subnet = subnet
    reset
    @ip_file = ip_file
    super(@ip_assignment)
  end

  #
  # Resets (clears) the IP database.
  #
  def reset
    @ip_assignment = { }
  end

  #
  # Loads the IP database from disk. Location is based on the `ip_file` accessor.
  #
  def load
    if File.exist?(ip_file)
      @ip_assignment = Marshal.load(File.binread(ip_file))
    end
  end

  #
  # Saves the IP database to disk. Location is based on the `ip_file` accessor.
  #
  def write
    FileUtils.mkdir_p(File.dirname(ip_file))
    File.binwrite(ip_file, Marshal.dump(@ip_assignment))
  end

  #
  # Gets the next unallocated IP, given an IP to start with.
  #
  def next_ip(arg)
    octets = arg.split(/\./, 4).map(&:to_i)
    octets[3] += 1
    raise "out of ips!" if octets[3] > 255
    return octets.map(&:to_s).join(".")
  end

  #
  # Gets the next un-used IP. This basically calls `next_ip` with knowledge of
  # the database.
  #
  def unused_ip
    ip = next_ip(@subnet)

    while ip_used?(ip)
      ip = next_ip(ip)
    end

    return ip
  end

  #
  # Predicate to determine if an IP is in use.
  #
  def ip_used?(ip)
    @ip_assignment.values.flatten.include?(ip)
  end

  #
  # Appends an IP to a role.
  #
  def assign_role_ip(role, ip)
    @ip_assignment[role] ||= []
    @ip_assignment[role].push(ip)
  end

  #
  # Removes the role and all associated IPs.
  #
  def delete_role(role)
    @ip_assignment.delete(role)
  end

  #
  # Gets all the IPs for a role, as an array of strings.
  #
  def get_role_ips(role)
    @ip_assignment[role] || []
  end

  #
  # Helper method for vagrant. Vagrant always occupies .1 of any subnet it
  # configures host-only networking on. This takes care of doing that.
  #
  def seed_vagrant_ips
    # vagrant requires that .1 be used by vagrant. ugh.
    dot_one_ip = @subnet.gsub(/\.\d+$/, '.1')
    unless ip_used?(dot_one_ip)
      assign_role_ip("vagrant-reserved", dot_one_ip)
    end
  end

  include GenericSupport
end

IPSupport.configure
IPSupport.singleton.load
