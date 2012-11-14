module GenericSupport
  # it's cool; this isn't absolutely evil or anything.
  def self.included(klass)
    class << klass
      attr_reader :singleton
      attr_accessor :supported_class

      def configure(&block)
        @singleton ||= self.supported_class.new
        @singleton.instance_eval(&block) if block
      end
    end

    klass.supported_class = klass
  end
end
