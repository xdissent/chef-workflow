Chef Workflow Toolkit
---------------------

A system to provide an encompassing toolkit and framework to work with chef
servers, their contents, and the networks of machines controlled by them. Your
test environment should look a lot like your production environment, and
chef-workflow lets you accomplish exactly that.

It is 3 major parts:

* This library, which is core functionality for unifying configuration of the
  system, provisioning machines and maintaining a source of truth that lives
  outside chef.
* [chef-workflow-tasklib](https://github.com/chef-workflow/chef-workflow-tasklib),
  which is a toolkit that leverages `rake` to provide a common interface for
  commanding chef-related operations.
* [chef-workflow-testlib](https://github.com/chef-workflow/chef-workflow-tasklib),
  which is a toolkit for real-world integration testing. No mocks, real
  machines, no bullshit.

Most of the Meat is on the Wiki
-------------------------------

Our [wiki](https://github.com/chef-workflow/chef-workflow/wiki) contains
a fair amount of information, including how to try chef-workflow without
actually doing anything more than cloning a repository and running a few
commands.

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

Author: [Erik Hollensbe](https://github.com/erikh)

These companies have assisted by donating time, financial resources, and
employment to those working on chef-workflow. Supporting OSS is really really
cool and we should reciprocate.

* [HotelTonight](http://www.hoteltonight.com) 
