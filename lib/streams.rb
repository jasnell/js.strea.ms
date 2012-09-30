##############################################
# Author: James M Snell (jasnell@gmail.com)  #
# License: Apache v2.0                       #
#                                            #
# A simple Activity Streams implementation.  #
#   (forgive me... my ruby's a bit rusty)    #
##############################################
REQUIRED_VERSION = '1.9.3'
raise "The streams gem currently requires Ruby version #{REQUIRED_VERSION} or higher" if RUBY_VERSION < REQUIRED_VERSION
require 'streams/activitystreams'
