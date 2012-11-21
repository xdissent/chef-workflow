#
# mixin for supplying a consistent interface to singleton configuration classes.
#

module GenericSupport
  #-- 
  # it's cool; this isn't absolutely evil or anything.
  #++
  def self.included(klass)
    class << klass
      # The singleton object that is supplying the current configuration.
      # Always reference this when working with classes that use this
      # interface.
      attr_reader :singleton

      # circular references, oh my
      attr_accessor :supported_class

      #
      # Configure the singleton. Instance evals a block that you can set stuff on.
      #
      def configure(&block)
        @singleton ||= self.supported_class.new
        @singleton.instance_eval(&block) if block
      end
    end

    klass.supported_class = klass
  end
end
