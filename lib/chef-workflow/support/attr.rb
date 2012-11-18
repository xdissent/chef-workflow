module AttrSupport
  def fancy_attr(name)
    class_eval <<-EOF
      attr_writer :#{name}
      def #{name}(arg=nil)
        if arg
          @#{name} = arg
        end

        @#{name}
      end
    EOF
  end
end
