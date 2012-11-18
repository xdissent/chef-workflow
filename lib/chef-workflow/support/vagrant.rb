require 'fileutils'
require 'vagrant/prison'
require 'chef-workflow/support/generic'

class VagrantSupport
  DEFAULT_VAGRANT_BOX = "http://files.vagrantup.com/precise64.box"
  DEFAULT_PRISON_DIR = File.join(Dir.pwd, '.chef-workflow', 'prisons')

  attr_accessor :prison_dir
  attr_reader :box

  def initialize(prison_dir=DEFAULT_PRISON_DIR, box_url=DEFAULT_VAGRANT_BOX)
    self.box_url = box_url
    @prison_dir = prison_dir
  end

  def box_url=(url)
    @box_url = url
    @box = File.basename(url).gsub('\.box', '')
  end

  def box_url(url=nil)
    if url
      self.box_url = url
    end

    @box_url
  end

  def create_prison_dir
    FileUtils.mkdir_p(@prison_dir)
  end

  def qualify_prison_file(prison_file)
    File.join(@prison_dir, prison_file)
  end

  def write_prison(prison_file, prison)
    create_prison_dir
    File.binwrite(
      qualify_prison_file(prison_file),
      Marshal.dump([prison.dir, prison.env_opts])
    )

    prison.name = prison_file
  end

  def read_prison(prison_file)
    prison_file = qualify_prison_file(prison_file)
    if File.exist?(prison_file)
      return Marshal.load(File.binread(prison_file))
    end

    return []
  end

  def remove_prison(prison_file)
    FileUtils.rm_f(qualify_prison_file(prison_file))
  end

  def destroy_prison(prison_file)
    prison_dir, prison_env_opts = read_prison(prison_file)

    if prison_dir and prison_env_opts
      prison = Vagrant::Prison.new(prison_dir)
      prison.configure_environment(prison_env_opts)
      prison.cleanup
      remove_prison(prison_file)
    end
  end

  include GenericSupport
end

VagrantSupport.configure
