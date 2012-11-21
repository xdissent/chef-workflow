Chef Workflow Toolkit
---------------------

This code is the common base of
[chef-workflow-tasklib](https://github.com/hoteltonight/chef-workflow-tasklib)
and
[chef-workflow-testlib](https://github.com/hoteltonight/chef-workflow-testlib).
Unless you are looking to create extensions to these two systems, or use the
libraries contained within, you would be better served (with rare exception) by
visiting these two projects for your testing and workflow needs.

Environment Variables
---------------------

This toolkit exposes a number of environment variables that you may want to set
to affect your experience using it:

* `CHEF_WORKFLOW_DEBUG` - set to an integer of 1-3, controls the amount of
  verbosity of reporting done in the libraries themselves. 1 usually amounts to
  diagnostic messages, 2 to full transactions (converges, bootstraps, VM
  provision detail), and 3 to more chatty individual pain points.
* `CHEF_CONFIG` - the path to your knife.rb. Note that if you've set this up in
  `KnifeSupport` or with `configure_knife` you should almost never need this.
* `TEST_CHEF_SUBNET` - specifies a /24 network that IP addresses are drawn from
  for local testing with VM systems. Note that this support is fairly crude --
  it's strongly suggested you use a proper /24 and make your last octet `0`.
  :)

Classes
-------

Expect this to be supplemented with linked RDoc that describes the API for each
class. For now, though, you'll have to generate the docs yourself or read the
source comments.

At the time of this writing there is not a very consistent namespacing method,
expect this to be corrected before the first release.

Utility libraries:
==================

* `Chef::Workflow::ConfigureHelper` - a mixin which provides easy-to-use methods
  of driving the various support configuration systems (see below).
* `AttrSupport` - a small mixin to supply chef-style instance variable mutators;
  the kind that are a little more convenient to use with `instance_eval`'d
  blocks.
* `DebugSupport` - mixin which defines a method called `if_debug` which is our
  gating mechanism for the `CHEF_WORKFLOW_DEBUG` environment variable.
* `GenericSupport` - mixin which keeps the configuration interface consistent by
  providing a `configure` class method that uses `instance_eval` and exposes a
  pre-configured object under `singleton` which can be manipulated.
* `KnifePluginSupport` - mixin which contains a routine called
  `init_knife_plugin` to simplify configuration of knife plugins, which can
  then be used as normal objects. Also configures a UI object with `StringIO`
  so that it can be communicated with optionally.

Configuration libraries:
========================

These all mixin `GenericSupport` and as a result are expected to be treated as
singletons, by accessing their `singleton` class method and configured with the
`configure` class method which `instance_eval`'s a block.

If you are using `chef-workflow-tasklib`, most of the bits here as you have
configured them can be described to you via `bundle exec rake chef:show_config`.

* `GeneralSupport` - "General" configuration attributes that are global to the
  entire system.
* `IPSupport` - Database for associating IP addresses with a server group. See
  discussion on the scheduler below for more information on server groups. This
  is generally not configured externally, but by tooling within the system.
* `KnifeSupport` - Most configuration regarding chef lives here, and additional
  network access.
* `VagrantSupport` - Specific bits related to using Vagrant, such as the box to
  be used for provisioning. 

Scheduler and VM
----------------

The Scheduler and VM system work together to make groups of machines easy to
provision. 

The scheduler is responsible for scheduling provisioning of groups of machines
which are interdependent with other machines. In other words when machine C
depends on B and A to be provisioned, and B and A have no dependencies, and
they are all scheduled at the same time, the scheduler will determine that A
and B have to be provisioned immediately and as soon as they are provisioned
successfully, it will attempt to provision C. Depending on the system
controlling the scheduler and its constraints, it can do this in a serial or
parallel fashion, the latter of which will attempt to provision as much as
possible at the same time, and as things finish will provision things that are
satisfied by what finished.

In other words, provisioning takes a lot of time in a test run, and the
scheduler tries very hard to make it take as little time as is reasonably
possible given your constraints and the constraints of the system.

It manages the actual act of provisioning through the VM system, which tracks
the state of what's currently provisioned, what has already successfully
provisioned (and presumed alive), and what is waiting to be provisoned. The VM
class itself is largely responsible for exposing this data to the scheduler,
and marshalling its state to disk in the event of a failure so things can be
cleaned up or resumed in the case of resources that will always be depended on
for a test run.

In other words, provisioning takes a lot of time in a test run, and the VM
system tries very hard to not add more time to this by tracking machines that
are already provisioned so they don't have to be re-provisioned, even between
runs. It also makes it easy to clean up a bad or stale test run.

Server Groups
=============

The VM system itself is a mapping of server groups to an array of provisioning
"commands", which are implemented as classes with a consistent interface
(visitors). A provisioning command may create a [vagrant
prison](https://github.com/hoteltonight/vagrant-prison) which contains all the
servers for that server group, complete with assigning them a host-only
interface and storing that with `IPSupport` so that it can be retrieved by
other bits of the test system or task system. Another provisioning command may
execute the in-code equivalent of `knife bootstrap` to build out your servers
with a role named after the server group. For de-provisioning, the provisioning
commands are played in reverse with a `shutdown` call applied to them.

Scheduler and VM libraries
==========================

* `Scheduler` - this is the meat; if you're driving a new testing system such
  as rspec, you'll want to get real familiar with the interface presented.
* `VM` - marshalling and delegation interface. Most of this is exposed to the
  scheduler interface.
* `VM::VagrantProvisioner` - creates a vagrant prison composed of n servers for
  a server group with a unique host-only ip for each server.
* `VM::KnifeProvisioner` - the provisioner equivalent of `knife bootstrap`, with
  additional sanity checks for both converge success and a waiting period for
  search indexing. On deprovision, deletes the nodes that were created. Will
  always try to bootstrap a group in parallel.

Contributing
------------

* fork the project
* make a branch
* add your stuff
* push your branch to your repo
* send a pull request

**Note:** modifications to gem metadata, author lists, and other credits
without rationale will be rejected immediately.

Credits
-------

This work is sponsored by [Hotel Tonight](http://hoteltonight.com) and is what
we use to test our infrastructure internally. Primarily authored by [Erik
Hollensbe](https://github.com/erikh).
