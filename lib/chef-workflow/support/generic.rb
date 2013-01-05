require 'singleton'
require 'deprecated'

module ChefWorkflow
  #
  # mixin for supplying a consistent interface to singleton configuration classes.
  #

  module GenericSupport
    def self.included(klass)
      klass.instance_eval do
        include Singleton

        def self.configure(&block)
          instance.instance_eval(&block) if block
        end

        def self.method_missing(sym, *args)
          instance.send(sym, *args)
        end

        def self.singleton
          instance
        end

        class << self
          include Deprecated
        end

        self.singleton_class.deprecated :singleton, "#{klass.name} class methods"
      end
    end
  end
end
