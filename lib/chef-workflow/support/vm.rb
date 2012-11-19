require 'chef-workflow/support/attr'
require 'chef-workflow/support/debug'

#
# This class mainly exists to track the run state of the Scheduler, and is kept
# simple so that the contents can be marshalled and restored from a file.
#
class VM
  DEFAULT_VM_FILE = File.join(Dir.pwd, '.chef-workflow', 'vms')

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
    self.vm_file ||= DEFAULT_VM_FILE

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
    self.class.vm_file ||= DEFAULT_VM_FILE
    marshalled = Marshal.dump(self)
    File.binwrite(self.class.vm_file, marshalled)
  end

  attr_reader :groups
  attr_reader :dependencies

  def initialize
    @groups        = { }
    @dependencies  = { }
  end
end
