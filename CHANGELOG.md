* 0.2.0 (unreleased)
  * Several missing validation checks and edge races were resolved.
  * Significant internals refactor -- things that were fast and simple when
    things were small got less fast and simple later.
    * Ruby's singleton library used instead of ugly hax
    * Replace marshal system with a tie-alike database layer built atop sqlite
    * Everything is namespaced under ChefWorkflow::
    * Most of the things that break API above were marked deprecated and will print warnings if used.
  * Provisioners now have a 'report' method which is used in informational
    tasks to describe the provisioner's unique data.
  * Fix for knife bootstrap actually DTRT in chef 10.18.x
  * Docs. Lots and Lots and Lots of Docs.

* 0.1.1 December 21, 2012
  * Fix gemspec. Here's to touching the stove.

* 0.1.0 December 21, 2012
  * Initial public release
