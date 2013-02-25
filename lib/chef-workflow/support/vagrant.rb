require 'fileutils'
require 'chef-workflow/support/generic'

module ChefWorkflow
  #
  # Vagrant configuration settings. Uses `GenericSupport`.
  #
  class VagrantSupport
    include ChefWorkflow::GenericSupport

    # The default vagrant box we use for provisioning.
    DEFAULT_VAGRANT_BOX = "http://files.vagrantup.com/precise32.box"

    # the calculated box, currently taken from the box_url. Expect this to change.
    attr_reader :box, :customizations

    #--
    # FIXME: support non-url boxes and ram configurations
    #++
    def initialize(box_url=DEFAULT_VAGRANT_BOX)
      self.box_url = box_url
      @customizations = []
    end

    #
    # Set or retrieve the box_url. See #box_url=.
    #
    def box_url(arg=nil)
      if arg
        self.box_url = arg
      end

      @box_url
    end

    #
    # Set the box_url. The box name is derived from the url currently.
    #
    def box_url=(url)
      @box_url = url
      @box = File.basename(url).gsub(/\.box$/, '')
    end

    def customize(arg = nil)
      @customizations << arg unless arg.nil?
    end
  end
end

ChefWorkflow::VagrantSupport.configure
