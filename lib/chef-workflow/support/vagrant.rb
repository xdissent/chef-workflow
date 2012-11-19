require 'fileutils'
require 'chef-workflow/support/generic'
require 'chef-workflow/support/attr'

class VagrantSupport
  DEFAULT_VAGRANT_BOX = "http://files.vagrantup.com/precise64.box"

  extend AttrSupport

  attr_reader :box
  fancy_attr :box_url

  # FIXME: support non-url boxes and ram configurations
  def initialize(box_url=DEFAULT_VAGRANT_BOX)
    self.box_url = box_url
  end

  def box_url=(url)
    @box_url = url
    @box = File.basename(url).gsub('\.box', '')
  end

  include GenericSupport
end

VagrantSupport.configure
