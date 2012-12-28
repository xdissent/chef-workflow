module ChefWorkflow
  #
  # mixin to assist with adding debug messages.
  #
  module DebugSupport

    CHEF_WORKFLOW_DEBUG_DEFAULT = 2

    #
    # Conditionally executes based on the level of debugging requested.
    #
    # `CHEF_WORKFLOW_DEBUG` in the environment is converted to an integer. This
    # integer is compared to the first argument. If it is higher than the first
    # argument, the block supplied will execute.
    #
    # Optionally, if there is a `else_block`, this block will be executed if the
    # condition is *not* met. This allows a slightly more elegant (if less ugly)
    # variant of dealing with the situation where if debugging is on, do one
    # thing, and if not, do something else.
    #
    # Examples:
    #
    #     if_debug(1) do
    #       $stderr.puts "Here's a debug message"
    #     end
    #
    # This will print "here's a debug message" to standard error if debugging is
    # set to 1 or greater.
    #
    #     do_thing = lambda { run_thing }
    #     if_debug(2, &do_thing) do
    #       $stderr.puts "Doing this thing"
    #       do_thing.call
    #     end
    #
    # If debugging is set to 2 or higher, "Doing this thing" will be printed to
    # standard error and then `run_thing` will be executed. If lower than 2 or
    # off, will just execute `run_thing`.
    #
    def if_debug(minimum=1, else_block=nil)
      $CHEF_WORKFLOW_DEBUG ||= 
        ENV.has_key?("CHEF_WORKFLOW_DEBUG") ? 
          ENV["CHEF_WORKFLOW_DEBUG"].to_i : 
          CHEF_WORKFLOW_DEBUG_DEFAULT

      if $CHEF_WORKFLOW_DEBUG >= minimum
        yield if block_given?
      elsif else_block
        else_block.call
      end
    end
  end
end
