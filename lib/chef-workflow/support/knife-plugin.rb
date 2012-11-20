require 'chef/application/knife'
require 'chef/knife'
require 'stringio'

module KnifePluginSupport
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
    cli.configure_chef

    return cli
  end
end
