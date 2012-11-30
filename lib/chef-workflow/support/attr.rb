#
# Mixin to make exposing attr modification via `instance_eval` easier.
#
module AttrSupport
  #
  # Defines an attribute that is both a standard writer, but with an overloaded
  # reader that accepts an optional argument. Equivalent to this code for `foo`:
  #
  #     attr_writer :foo
  #
  #     def foo(*args)
  #       if args.count > 0
  #         @foo = arg
  #       end
  #
  #       @foo
  #     end
  #
  def fancy_attr(name)
    class_eval <<-EOF
      attr_writer :#{name}
      def #{name}(*args)
        if args.count > 0
          @#{name} = arg
        end

        @#{name}
      end
    EOF
  end
end
