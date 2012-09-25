## js.strea.ms

A simple JavaScript Activity Streams format implementation. The goal 
here is to provide a reasonably straightforward means of producing 
Activity Streams objects.

For example... a basic Activity statement can be produced using:

``` javascript
var as = 
  AS.activity()
    .actor(AS.person().displayName("James"))
    .verb("post")
    .object(AS.note().content("test"))
    .get();

print(as.write());
```

The pattern is basic:

 * Various methods on the AS object return AS.Builder instances... 
   while these are not strictly necessary for a JavaScript environment,
   the AS.Builder object provides generally type-safe construction 
   of Activity Streams objects supporting standard properties. If,
   for instance, you pass in a String to a property that typically
   requires an AS.Object instance, an error will be thrown. Another
   nice element of the AS.Builder is that it supports a fluent
   construction pattern.
 * Once you've set all your properties, call the AS.Builder objects
   get() method to retrieve the constructed object. Typically, these
   will be instances of the AS.Object class. There aren't any tricks
   to using this object, really. 
 * Use the AS.Object's write() method to retrieve the serialized JSON
   representation.

The Factory methods supported include:

 * AS.make([props]) - Generates a generic AS.Builder that will produce a normal JavaScript Object
 * AS.obj([objectType,props]) - Generates an AS.Builder that produces an AS.Object instance
 * AS.link() - Generates an AS.Object whose "objectType":"link"
 * AS.links() - Generates an AS.Builder that builds a collection of Link objects
 * AS.mediaLink() - Generates an AS.Builder that produces a MediaLink object
 * AS.activity() - Generates an AS.Builder that produces an Activity object
 * AS.alert() - Generates an AS.Object whose "objectType":"alert"
 * AS.application() - Generates an AS.Object whose "objectType":"application"
 * AS.article() - Generates an AS.Object whose "objectType":"article"
 * AS.audio() - Generates an AS.Object whose "objectType":"audio"
 * AS.badge() - Generates an AS.Object whose "objectType":"badge"
 * AS.bookmark() - Generates an AS.Object whose "objectType":"bookmark"
 * AS.collection() - Generates an AS.Object whose "objectType":"collection"
 * AS.comment() - Generates an AS.Object whose "objectType":"comment"
 * AS.device() - Generates an AS.Object whose "objectType":"device"
 * AS.event() - Generates an AS.Object whose "objectType":"event"
 * AS.file() - Generates an AS.Object whose "objectType":"file"
 * AS.game() - Generates an AS.Object whose "objectType":"game"
 * AS.group() - Generates an AS.Object whose "objectType":"group"
 * AS.image() - Generates an AS.Object whose "objectType":"image"
 * AS.issue() - Generates an AS.Object whose "objectType":"issue"
 * AS.job() - Generates an AS.Object whose "objectType":"job"
 * AS.note() - Generates an AS.Object whose "objectType":"note"
 * AS.offer() - Generates an AS.Object whose "objectType":"offer"
 * AS.organization() - Generates an AS.Object whose "objectType":"organization"
 * AS.page() - Generates an AS.Object whose "objectType":"page"
 * AS.person() - Generates an AS.Object whose "objectType":"person"
 * AS.place() - Generates an AS.Object whose "objectType":"place"
 * AS.position() - Generates a generic object for use with the "place" object's position property
 * AS.address() - Generates a generic object for use with the "place" object's address property
 * AS.process() - Generates an AS.Object whose "objectType":"process"
 * AS.product() - Generates an AS.Object whose "objectType":"product"
 * AS.question() - Generates an AS.Object whose "objectType":"question"
 * AS.review() - Generates an AS.Object whose "objectType":"review"
 * AS.service() - Generates an AS.Object whose "objectType":"service"
 * AS.task() - Generates an AS.Object whose "objectType":"task"
 * AS.video() - Generates an AS.Object whose "objectType":"video"



## activitystreams.rb

A simple Ruby Activity Streams implementation

Example:
require 'activitystreams'
include ActivityStreams
 
``` ruby
#!/Users/james/.rvm/rubies/ruby-1.9.3-p194/bin/ruby
$: << '.' if !$:.include? '.'
##############################################
# Author: James M Snell (jasnell@gmail.com)  #
# License: Apache v2.0                       #
##############################################
require 'activitystreams'
require 'optparse'

options = {}
optparse = OptionParser.new do|opts|
 opts.banner = "Usage: note [options] content"
 options[:name] = nil
 opts.on( '-n', '--name NAME', 'The name' ) do |x|
   options[:name] = x
 end
 opts.on( '-h', '--help', 'Display this screen' ) do
   puts opts
   exit
 end
end
optparse.parse!

include ActivityStreams
 
STDOUT << activity {
  pretty
  verb :post
  actor person {
    display_name options[:name]
  }
  obj note {
    content ARGV.shift
  }
}
```
