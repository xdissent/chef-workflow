require 'fileutils'
require 'erb'
require 'chef-workflow/support/generic'
require 'chef-workflow/support/general'
require 'chef-workflow/support/debug'
require 'chef-workflow/support/attr'

module ChefWorkflow
  #
  # Configuration class for chef tooling and SSH interaction. Uses `GenericSupport`.
  #
  class KnifeSupport
    include ChefWorkflow::DebugSupport
    extend ChefWorkflow::AttrSupport
    include ChefWorkflow::GenericSupport

    # defaults, yo
    DEFAULTS = {
      :search_index_wait      => 60,
      :cookbooks_path         => File.join(Dir.pwd, 'cookbooks'),
      :chef_config_path       => File.join(ChefWorkflow::GeneralSupport.workflow_dir, 'chef'),
      :knife_config_path      => File.join(ChefWorkflow::GeneralSupport.workflow_dir, 'chef', 'knife.rb'),
      :roles_path             => File.join(Dir.pwd, 'roles'),
      :environments_path      => File.join(Dir.pwd, 'environments'),
      :data_bags_path         => File.join(Dir.pwd, 'data_bags'),
      :ssh_user               => "vagrant",
      :ssh_password           => "vagrant",
      :ssh_identity_file      => nil,
      :use_sudo               => true,
      :test_environment       => "vagrant",
      :test_recipes           => [],
      :webui_password         => "chefwkflw"
    }

    DEFAULTS[:knife_config_template] = <<-EOF
    log_level                :info
    log_location             STDOUT
    node_name                'test-user'
    client_key               File.join('<%= KnifeSupport.chef_config_path %>', 'admin.pem')
    validation_client_name   'chef-validator'
    validation_key           File.join('<%= KnifeSupport.chef_config_path %>', 'validation.pem')
    chef_server_url          'http://<%= IPSupport.get_role_ips("chef-server").first %>:4000'
    environment              '<%= KnifeSupport.test_environment %>'
    cache_type               'BasicFile'
    cache_options( :path => File.join('<%= KnifeSupport.chef_config_path %>', 'checksums' ))
    cookbook_path            [ '<%= KnifeSupport.cookbooks_path %>' ]
    EOF

    attr_reader :attributes

    def initialize
      @attributes = { }

      DEFAULTS.each do |key, value|
        add_attribute(key, value)
      end
    end
      
    #
    # Helper method to allow extensions to add attributes to this class.
    # Takes an attribute name and a default which will be set initially,
    # intended to be overridden by the user if necessary.
    #
    #--
    # FIXME Move all the user-configurable stuff to its own support system
    #++
    def add_attribute(attr_name, default)
      @attributes[attr_name] = default
    end

    def method_missing(sym, *args)
      attr_name = sym.to_s.sub(/=$/, '').to_sym
      assignment = sym.to_s.end_with?("=")

      if @attributes.has_key?(attr_name)
        if assignment or args.count > 0
          @attributes[attr_name] = args[0]
        else
          @attributes[attr_name]
        end
      else
        raise "Attribute #{attr_name} does not exist"
      end
    end

    #
    # Writes out a knife.rb based on the settings in this configuration. Uses the
    # `knife_config_path` and `chef_config_path` to determine where to write it.
    #
    def build_knife_config
      FileUtils.mkdir_p(chef_config_path)
      File.binwrite(knife_config_path, ERB.new(knife_config_template).result(binding))
    end
  end
end

ChefWorkflow::KnifeSupport.configure
