# hierarchy.rb — formerly patched boot-time class/module wiring needed before
# lib/core/4.0/ files could load. Now empty: each class/module declares its own
# superclass, includes, and methods in lib/core/4.0/. See vm.rb#load_core for
# the load order that ensures correct sequencing (module.rb first, then kernel.rb
# before object.rb, comparable.rb before string.rb, etc.).
