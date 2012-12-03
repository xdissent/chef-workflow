require 'chef/application/knife'
require 'chef/knife'
require 'stringio'

#
# Mixin to add methods to assist with creating knife plugins.
#
module KnifePluginSupport

  #
  # Given a class name for a plugin compatible with the Chef::Knife interface,
  # initializes it and makes it available for execution. It also overrides the
  # `ui` object to use `StringIO` objects, which allow you to choose when and
  # if you display the output of the commands by referencing
  # `obj.ui.stdout.string` and similar calls.
  #
  # The second argument is an array of arguments to the command, such as they
  # would be presented to a command line tool as `ARGV`.
  #
  def init_knife_plugin(klass, args)
    klass.options = Chef::Application::Knife.options.merge(klass.options)
    klass.load_deps
    cli = klass.new(args)
    cli.ui = Chef::Knife::UI.new(
      StringIO.new('', 'w'), 
      StringIO.new('', 'w'),
      StringIO.new('', 'r'),
      cli.config
    )

    return cli
  end
end
