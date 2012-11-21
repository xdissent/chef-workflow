require 'set'
require 'thread'
require 'timeout'
require 'chef-workflow/support/attr'
require 'chef-workflow/support/debug'
require 'chef-workflow/support/vm'

#
# This is a scheduler for provisioners. It can run in parallel or serial mode,
# and is dependency-based, that is, it will only schedule items for execution
# which have all their dependencies satisfied and items that haven't will wait
# to execute until that happens.
#
class Scheduler
  extend AttrSupport
  include DebugSupport

  fancy_attr :serial

  def initialize(at_exit_hook=true)
    @solved_mutex   = Mutex.new
    @serial         = false
    @solver_thread  = nil
    @working        = { }
    @waiters        = Set.new
    @queue          = Queue.new
    @vm             = VM.load_from_file || VM.new 
    if at_exit_hook
      at_exit { write_state }
    end
  end

  def write_state 
    @vm.save_to_file
    # FIXME not the best place to do this, but we have additional problems if
    #       we don't
    IPSupport.singleton.write
  end

  #
  # Helper to assist with dealing with a VM object
  #
  def solved
    @vm.provisioned
  end

  #
  # Helper to assist with dealing with a VM object
  #
  def vm_groups
    @vm.groups
  end
  
  #
  # Helper to assist with dealing with a VM object
  #
  def vm_dependencies
    @vm.dependencies
  end

  #
  # Helper to assist with dealing with a VM object
  #
  def vm_working
    @vm.working
  end

  #
  # Schedule a group of VMs for provision. This takes a group name, which is a
  # string, a provisioner object, and a list of string dependencies. If
  # anything in the dependencies list hasn't been pre-declared, it refuses to
  # continue.
  #
  def schedule_provision(group_name, provisioner, dependencies=[])
    return nil if vm_groups[group_name]
    provisioner = [provisioner] unless provisioner.kind_of?(Array)
    provisioner.each { |x| x.name = group_name }
    vm_groups[group_name] = provisioner

    unless dependencies.all? { |x| vm_groups.has_key?(x) }
      raise "One of your dependencies for #{group_name} has not been pre-declared. Cannot continue"
    end

    vm_dependencies[group_name] = dependencies.to_set
    @waiters.add(group_name)
  end

  #
  # Sleep until this list of dependencies are resolved. In parallel mode, will
  # raise if an exeception occurred while waiting for these resources. In
  # serial mode, wait_for just returns nil.
  #
  def wait_for(*dependencies)
    return nil if @serial

    dep_set = dependencies.to_set
    until dep_set & solved == dep_set
      sleep 1
      @solver_thread.join unless @solver_thread.alive?
    end
  end

  #
  # Helper method for scheduling. Wraps items in a timeout and immediately
  # checks all running workers for exceptions, which are immediately bubbled up
  # if there are any. If do_loop is true, it will retry the timeout.
  #
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

  #
  # Start the scheduler. In serial mode this call will block until the whole
  # dependency graph is satisfied, or one of the provisions fails, at which
  # point an exception will be raised. In parallel mode, this call completes
  # immediately, and you should use #wait_for to control main thread flow.
  #
  # This call also installs a SIGINFO (Ctrl+T in the terminal on macs) and
  # SIGUSR2 handler which can be used to get information on the status of
  # what's solved and what's working. 
  #
  def run
    # short circuit if we're not serial and already running
    return if @solver_thread and !@serial

    handler = lambda do
      p ["solved:", solved]
      p ["working:", @working]
    end

    %w[USR2 INFO].each { |sig| trap(sig, &handler) }

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
            @solved_mutex.synchronize do
              solved.add(r)
              @working.delete(r)
              vm_working.delete(r)
            end
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

  #
  # Instructs the scheduler to stop. Note that this is not an interrupt, and
  # the queue will still be exhausted before terminating.
  #
  def stop
    if @serial
      @queue << nil
    else
      @working.values.map { |v| v.join rescue nil }
      @queue << nil
      @solver_thread.join rescue nil
    end
  end

  #
  # This method determines what 'waiters', or provisioners that cannot
  # provision yet because of unresolved dependencies, can be executed.
  #
  def service_resolved_waiters
    @waiters -= (@working.keys.to_set + solved)

    @waiters.each do |group_name|
      if solved & vm_dependencies[group_name] == vm_dependencies[group_name]
        if_debug do
          $stderr.puts "Provisioning #{group_name}"
        end

        provisioner = vm_groups[group_name]

        provision_block = lambda do
          # FIXME maybe a way to specify initial args?
          args = nil
          provisioner.each do |this_prov|
            unless args = this_prov.startup(args)
              raise "Could not provision #{group_name}"
            end
          end
          @queue << group_name
        end

        vm_working.add(group_name)

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

  #
  # Teardown a single group -- modifies the solved formula. Be careful to
  # resupply dependencies if you use this, as nothing will resolve until you
  # resupply it.
  #
  # This takes an optional argument to wait for the group to be solved before
  # attempting to tear it down. Setting this to false effectively says, "I know
  # what I'm doing", and you should feel bad if you file an issue because you
  # supplied it.
  #

  def teardown_group(group_name, wait=true)
    wait_for(group_name) if wait

    dependent_items = vm_dependencies.partition { |k,v| v.include?(group_name) }.first.map(&:first)

    if_debug do
      $stderr.puts "Trying to terminate #{group_name}, found #{dependent_items.inspect} depending on it"
    end

    @solved_mutex.synchronize do
      dependent_and_working = @working.keys & dependent_items

      if dependent_and_working.count > 0
        $stderr.puts "#{dependent_and_working.inspect} are depending on #{group_name}, which you are trying to deprovision."
        $stderr.puts "We can't resolve this problem for you, and future converges may fail during this run that would otherwise work."
        $stderr.puts "Consider using wait_for to better control the dependencies, or turning serial provisioning on."
      end

      deprovision_group(group_name)
    end

  end

  #
  # Performs the deprovision of a group by replaying its provision strategy
  # backwards and applying the #shutdown method instead of the #startup method.
  # Removes it from the various state tables if true is set as the second
  # argument, which is the default.
  #
  def deprovision_group(group_name, clean_state=true)
    provisioner = vm_groups[group_name]

    provisioner.reverse.each do |this_prov|
      unless this_prov.shutdown
        if_debug do
          $stderr.puts "Could not deprovision group #{group_name}."
        end
      end
    end

    if clean_state
      solved.delete(group_name)
      vm_dependencies.delete(group_name)
      vm_groups.delete(group_name)
    end
  end

  #
  # Instruct all the provisioners to tear down. Calls #stop as its first action.
  #
  # This is always done serially. For sanity.
  #
  def teardown
    stop

    (solved + vm_working).each do |group_name|
      if_debug do
        $stderr.puts "Attempting to deprovision group #{group_name}"
      end

      deprovision_group(group_name, false) # clean this after everything finishes
    end

    @vm.clean
    write_state
  end
end
