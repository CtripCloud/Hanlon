# this file defines the list of classes to be loaded under slice
# this is dependency ordering is required for the code to run under compiled model of class loading under jruby
# here all the load files are maintained in the order of dependency
#
# This can be replace if we find a more meaningful method of loading classes

# level 1
require 'slice/tag'
require 'slice/policy'
require 'slice/node'
require 'slice/model'
require 'slice/vmodel'
require 'slice/config'
require 'slice/broker'
require 'slice/active_model'
require 'slice/image'

