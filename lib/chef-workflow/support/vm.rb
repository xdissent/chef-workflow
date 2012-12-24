require 'set'
require 'fileutils'
require 'chef-workflow/support/general'
require 'chef-workflow/support/attr'
require 'chef-workflow/support/debug'

#--
# XXX see the dynamic require at the bottom
#++

#
# This class mainly exists to track the run state of the Scheduler, and is kept
# simple so that the contents can be marshalled and restored from a file.
#
class VM
  class << self
    extend AttrSupport
    fancy_attr :vm_file
  end

  include DebugSupport
  extend AttrSupport

  #
  # If a file exists that contains a VM object, load it. Use VM.vm_file to
  # control the location of this file.
  #
  def self.load_from_file
    vm_file = GeneralSupport.singleton.vm_file

    if File.file?(vm_file)
      return Marshal.load(File.binread(vm_file || DEFAULT_VM_FILE))
    end

    return nil
  end
 
  #
  # Save the marshalled representation to a file. Use VM.vm_file to control the
  # location of this file.
  #
  def save_to_file
    vm_file = GeneralSupport.singleton.vm_file
    marshalled = Marshal.dump(self)
    FileUtils.mkdir_p(File.dirname(vm_file))
    File.binwrite(vm_file, marshalled)
  end

  # the vm groups and their provisioning lists.
  attr_reader :groups
  # the dependencies that each vm group depends on
  attr_reader :dependencies
  # the set of provisioned (solved) groups
  attr_reader :provisioned
  # the set of provisioning (working) groups
  attr_reader :working

  def clean
    @groups        = { }
    @dependencies  = { }
    @provisioned   = Set.new
    @working       = Set.new
  end

  alias initialize clean
end

# XXX require all the provisioners -- marshal will blow up unless this is done.
Dir[File.join(File.expand_path(File.dirname(__FILE__)), 'vm', '*')].each do |x|
  require x if File.file?(x)
end
