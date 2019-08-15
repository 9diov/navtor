## Steps to refactor
* Turn UI class's internal state to immutable Value class
* Turn most of UI class's methods to pure functions by:
  * Remove reference to @file_manager and explicitly pass the arguments to the functions
  * For side effects, returns an `action` symbol instead of calling @file_manager directly
  * Reduce number of methods that reference instance variables

## Things learned
* Side effects with state mutations are all over the place which is hard to test and debug


