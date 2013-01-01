require 'fileutils'
require 'singleton'
#require 'chef-workflow/support/generic'
require 'chef-workflow/support/attr'
require 'chef-workflow/support/db'

ENV["TEST_CHEF_SUBNET"] ||= "10.10.10.0"

module ChefWorkflow
  #
  # IP allocation database. Uses `GenericSupport`.
  #
  class IPSupport
    extend ChefWorkflow::AttrSupport
    include Singleton

    def self.singleton
      return instance
    end

    def self.configure(&block)
      instance.instance_eval(&block) if block
    end

    def self.method_missing(sym, *args)
      instance.send(sym, *args)
    end

    ##
    # :attr:
    #
    # The subnet used for calculating assignable IP addresses. You really want to
    # set `TEST_CHEF_SUBNET` in your environment instead of changing this.
    #
    fancy_attr :subnet

    def initialize(subnet=ENV["TEST_CHEF_SUBNET"])
      @subnet = subnet
      @db = ChefWorkflow::DatabaseSupport.instance
      create_table
    end

    def create_table
      @db.execute <<-EOF
      create table if not exists ips (
        id integer not null primary key autoincrement,
        role_name varchar(255) not null,
        ip_addr varchar(255) not null,
        UNIQUE(role_name),
        UNIQUE(ip_addr)
      )
      EOF
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
      @db.execute("select count(*) from ips where ip_addr=?", [ip]).first.first > 0 rescue nil
    end

    #
    # Appends an IP to a role.
    #
    def assign_role_ip(role, ip)
      @db.execute("insert into ips (role_name, ip_addr) values (?, ?)", [role, ip])
    end

    #
    # Removes the role and all associated IPs.
    #
    def delete_role(role)
      @db.execute("delete from ips where role_name=?", [role])
    end

    #
    # Gets all the IPs for a role, as an array of strings.
    #
    def get_role_ips(role)
      @db.execute("select ip_addr from ips where role_name=? order by id", [role]).map(&:first)
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

    #include ChefWorkflow::GenericSupport
  end
end

ChefWorkflow::IPSupport.configure
