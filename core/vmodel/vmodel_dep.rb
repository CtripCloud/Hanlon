# this file defines the list of classes to be loaded under vmodel
# this is dependency ordering is required for the code to run under compiled vmodel of class loading under jruby
# here all the load files are maintained in the order of dependency
#
# This can be replace if we find a more meaningful method of loading classes

# level 1
require 'vmodel/base'

# level 2
require 'vmodel/hp'
require 'vmodel/huawei'
