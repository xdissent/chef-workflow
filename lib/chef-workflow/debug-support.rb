module DebugSupport
  def if_debug(minimum=1)
    $CHEF_WORKFLOW_DEBUG ||= ENV["CHEF_WORKFLOW_DEBUG"].to_i
    $CHEF_WORKFLOW_DEBUG ||= 0

    if $CHEF_WORKFLOW_DEBUG >= minimum
      yield if block_given?
    end
  end
end
