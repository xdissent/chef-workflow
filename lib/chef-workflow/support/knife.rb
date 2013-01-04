require 'fileutils'
require 'erb'
require 'chef-workflow/support/generic'
require 'chef-workflow/support/general'
require 'chef-workflow/support/debug'

module ChefWorkflow
  #
  # Configuration class for chef tooling and SSH interaction. Uses `GenericSupport`.
  #
  class KnifeSupport
    include ChefWorkflow::GenericSupport
    include ChefWorkflow::DebugSupport

    # defaults, yo
    DEFAULTS = {
      :search_index_wait      => 60,
      :cookbooks_path         => File.join(Dir.pwd, 'cookbooks'),
      :chef_config_path       => File.join(ChefWorkflow::GeneralSupport.singleton.workflow_dir, 'chef'),
      :knife_config_path      => File.join(ChefWorkflow::GeneralSupport.singleton.workflow_dir, 'chef', 'knife.rb'),
      :roles_path             => File.join(Dir.pwd, 'roles'),
      :environments_path      => File.join(Dir.pwd, 'environments'),
      :data_bags_path         => File.join(Dir.pwd, 'data_bags'),
      :ssh_user               => "vagrant",
      :ssh_password           => "vagrant",
      :ssh_identity_file      => nil,
      :use_sudo               => true,
      :test_environment       => "vagrant",
      :test_recipes           => []
    }

    DEFAULTS[:knife_config_template] = <<-EOF
    log_level                :info
    log_location             STDOUT
    node_name                'test-user'
    client_key               File.join('<%= KnifeSupport.singleton.chef_config_path %>', 'admin.pem')
    validation_client_name   'chef-validator'
    validation_key           File.join('<%= KnifeSupport.singleton.chef_config_path %>', 'validation.pem')
    chef_server_url          'http://<%= IPSupport.get_role_ips("chef-server").first %>:4000'
    environment              '<%= KnifeSupport.singleton.test_environment %>'
    cache_type               'BasicFile'
    cache_options( :path => File.join('<%= KnifeSupport.singleton.chef_config_path %>', 'checksums' ))
    cookbook_path            [ '<%= KnifeSupport.singleton.cookbooks_path %>' ]
    EOF

    #
    # Helper method to allow extensions to add attributes to this class. Could
    # probably be replaced by `AttrSupport`. Takes an attribute name and a
    # default which will be set initially, intended to be overridden by the user
    # if necessary.
    #
    def self.add_attribute(attr_name, default)
      ChefWorkflow::KnifeSupport.configure

      DEFAULTS[attr_name] = default # a little inelegant, but it works.

      # HACK: no good way to hook this right now, revisit later.
      str = ""
      if attr_name.to_s == "knife_config_path"
        str = <<-EOF
          def #{attr_name}=(arg)
            @#{attr_name} = arg
            ENV["CHEF_CONFIG"] = arg
          end

          def #{attr_name}(arg=nil)
            if arg
              @#{attr_name} = arg
              ENV["CHEF_CONFIG"] = arg
            end
            
            @#{attr_name}
          end
        EOF
      else
        str = <<-EOF
          def #{attr_name}=(arg)
            @#{attr_name} = arg
          end

          def #{attr_name}(arg=nil)
            if arg
              @#{attr_name} = arg
            end
            
            @#{attr_name}
          end
        EOF
      end

      ChefWorkflow::KnifeSupport.singleton.instance_eval str
      ChefWorkflow::KnifeSupport.singleton.send(attr_name, default)
    end
    
    DEFAULTS.each { |key, value| add_attribute(key, value) }

    def initialize(options={})
      DEFAULTS.each do |key, value|
        instance_variable_set(
          "@#{key}", 
          options.has_key?(key) ? options[key] : DEFAULTS[key]
        )
      end
    end

    def method_missing(sym, *args)
      if_debug(2) do
        $stderr.puts "#{self.class.name}'s #{sym} method was referenced while trying to configure #{self.class.name}"
        $stderr.puts "#{self.class.name} has not been configured to support this feature."
        $stderr.puts "This is probably due to it being dynamically added from a rake task, and you're running the test suite."
        $stderr.puts "It's probably harmless. Expect a better solution than this debug message soon."
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
