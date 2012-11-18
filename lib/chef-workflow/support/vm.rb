require 'set'
require 'thread'
require 'timeout'
require 'fileutils'
require 'chef-workflow/support/attr'
require 'chef-workflow/support/debug'

class VMSupport
  DEFAULT_VM_FILE = File.join(Dir.pwd, '.chef-workflow', 'vms')

  class << self
    extend AttrSupport
    fancy_attr :vm_file
  end

  extend AttrSupport
  include DebugSupport

  def self.load
    self.vm_file ||= DEFAULT_VM_FILE

    if File.file?(vm_file)
      return Marshal.load(File.binread(vm_file || DEFAULT_VM_FILE))
    end

    return nil
  end

  fancy_attr :serial

  def initialize
    @serial           = false
    @vm_groups        = { }
    @vm_dependencies  = { }
    @solver_thread    = nil
    @waiters          = Set.new
    @working          = { }
    @solved           = Set.new
    @queue            = Queue.new
  end

  def save
    self.class.vm_file ||= DEFAULT_VM_FILE
    marshalled = Marshal.dump(self)
    File.binwrite(self.class.vm_file, marshalled)
  end

  def schedule_provision(group_name, provisioner, dependencies=[])
    provisioner.name = group_name # FIXME remove
    @vm_groups[group_name] = provisioner

    unless dependencies.all? { |x| @vm_groups.has_key?(x) }
      raise "One of your dependencies for #{group_name} has not been pre-declared. Cannot continue"
    end

    @vm_dependencies[group_name] = dependencies.to_set
    @waiters.add(group_name)
  end

  def wait_for(*dependencies)
    return nil if @serial

    dep_set = dependencies.to_set
    until dep_set & @solved == dep_set
      sleep 1
      @solver_thread.join unless @solver_thread.alive?
    end
  end

  def with_timeout(do_loop=true)
    Timeout.timeout(10) do
      if @working.values.reject(&:alive?).size > 0
        @working.select { |k,v| !v.alive? }.values.map(&:join)
      end

      yield
    end
  rescue TimeoutError
    retry if do_loop
  end

  def run
    trap("INFO") do
      p ["solved:", @solved]
      p ["working:", @working]
    end

    queue_runner = lambda do
      run = true

      while run
        ready = []

        if @queue.empty?
          if @serial
            return
          else
            with_timeout { ready << @queue.shift if ready.empty? }
          end
        end

        while !@queue.empty?
          ready << @queue.shift
        end

        ready.each do |r|
          if r
            @solved.add(r)
            @working.delete(r)
          else
            run = false
          end
        end

        service_resolved_waiters if run
      end
    end

    if @serial
      service_resolved_waiters
      queue_runner.call
    else
      @solver_thread = Thread.new do
        with_timeout(false) { service_resolved_waiters }
        queue_runner.call
      end
    end
  end

  def stop
    if @serial
      @queue << nil
    else
      @working.values.map { |v| v.join rescue nil }
      @queue << nil
      @solver_thread.join rescue nil
    end
  end

  def service_resolved_waiters
    @waiters -= (@working.keys.to_set + @solved)

    @waiters.each do |group_name|
      if @solved & @vm_dependencies[group_name] == @vm_dependencies[group_name]
        if_debug do
          $stderr.puts "Provisioning #{group_name}"
        end

        provisioner = @vm_groups[group_name]

        provision_block = lambda do
          raise "Could not provision #{group_name}" unless provisioner.startup
          @queue << group_name
        end

        if @serial
          # HACK: just give the working check something that will always work.
          #       Probably should just mock it.
          @working[group_name] = Thread.new { sleep }
          provision_block.call
        else
          @working[group_name] = Thread.new(&provision_block)
        end
      end
    end
  end

  def teardown
    stop

    t = []

    @solved.each do |group_name|
      if_debug do
        $stderr.puts "Attempting to terminate VM group #{group_name}"
      end

      provisioner = @vm_groups[group_name]

      provisioner_block = lambda do
        unless provisioner.shutdown
          if_debug do
            $stderr.puts "Could not terminate VM group #{group_name}."
          end
        end
      end

      if @serial
        provisioner_block.call
      else
        t.push(Thread.new(&provisioner_block))
      end
    end

    unless @serial
      t.map(&:join)
    end
  end
end

class TestProvisioner
  attr_accessor :name

  def startup
    $stderr.puts "running scheduled startup"
    sleep 10
    true
  end

  def shutdown
    $stderr.puts "running scheduled shutdown"
    true
  end
end

$CHEF_WORKFLOW_DEBUG = 1

v = VMSupport.new
v.schedule_provision("foo", TestProvisioner.new)
v.schedule_provision("bar", TestProvisioner.new)
v.schedule_provision("quux", TestProvisioner.new, %w[foo])
v.schedule_provision("fart", TestProvisioner.new, %w[bar])
v.schedule_provision("poop", TestProvisioner.new, %w[bar quux])
v.schedule_provision("poopie", TestProvisioner.new, %w[foo bar])
v.schedule_provision("hi", TestProvisioner.new)
v.schedule_provision("longcat", TestProvisioner.new, %w[poop poopie hi])
v.run

begin
  v.wait_for("longcat") rescue nil
  v.teardown
rescue Interrupt
end
