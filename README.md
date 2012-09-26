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
  pretty                          # causes the json to be pretty printed
  verb :post                      # verb is "post"
  actor person {                  # sets the actor property, person object
    display_name options[:name]   # name is pulled from the command line args
  }
  obj note {                      # sets the object property, note object
    content ARGV.shift            # content is pulled from the command line args
  }
}
```

The basic idea here is to provide a simple way of generating Activity 
Streams objects quickly and efficiently. This code currently only does
generation of objects, it doesn't do parsing. Use the json library to 
handling the parsing for now.

For generation, we essentially use an extensible domain specific language
model that is based directly on the core [JSON Activity Streams][1] and
[Activity Streams Schema][2] specifications.

First step, is to pull in the activitystreams.rb file... That's simple enough:

``` ruby
require 'activitystreams'
include ActivityStreams
```

Including the ActivityStreams module will effectively initialize the domain
specific language. To begin creating an Activity, we simply call the 
<tt>activity</tt> function and pass in the block that will provide it's 
detail. When the block returns, an *Immutable* ActivityStreams::ASObj instance
will be returned. Allow me to stress the *Immutable* part. Once an Activity
Streams object is created, it cannot be changed. You have to create a copy
and edit that if you wish to make changes. So whatever build up you need to
do on that object must happen within the block.

``` ruby
my_activity = activity {
  verb :post
  actor person { display_name 'James' }
  obj note { content 'This is content' }
}
```

As illustrated in the example, the properties on the activity are set by calling 
methods within the block. For instance <tt>verb :post</tt> sets the "verb" property
of the activity equal to the value "post". 

Note how the actor property is set: <tt>actor person { display_name 'James' }</tt>

The call to <tt>person</tt> is actually another function call that creates an
Activity Streams person object (as defined by the [Schema][2]). The block that 
follows sets the properties on that person object. So the example is basically
saying The "actor" is a "person" with "displayName" equal to "James"

Calling the standard to_s method on the ASObj instance will generate the JSON so 
if we call

``` ruby
STDOUT << my_activity
```

What we'll end up with is:

``` json
{"verb":"post", "actor": {"objectType": "person", "displayName": "James"}, "object": {"objectType": "note", "content": "This is content"}}
```

That's not exactly easy to read so let's format it up a bit by placing a call 
to the <tt>pretty</tt> function within the activity block.

``` ruby
my_activity = activity {
  pretty
  verb :post
  actor person { display_name 'James' }
  obj note { content 'This is content' }
}

STDOUT << my_activity
```

Now what we'll get is a nicely formatted Activity...

``` json
{
  "verb":"post", 
  "actor": {
    "objectType": "person", 
    "displayName": "James"
  }, 
  "object": {
    "objectType": "note", 
    "content": "This is content"
  }
}
```

All of the core object types defined by the [Schema][1] are supported, and the
property methods that can be called within the block associated with each are 
specific to each object type. For instance, suppose you wanted to add an
attachment to that note object, you can use the binary object to attach base64
and compressed binary data to the note as in the following example:

``` ruby
my_activity = activity {
  pretty
  verb :post
  actor person { display_name 'James' }
  obj note { 
    content 'This is content' 
    attachment binary {
      # binary attachments are base64 and compressed automatically for you
      File.open('activity_note','r') { |f| 
        data f, :deflate
      } 
    }
  }
}

STDOUT << my_activity
```

There are many properties within an Activity Stream document that have fairly
specific data type requirements. For instance, the <tt>id</tt> property is 
required to be an absolute IRI. The <tt>location</tt> property is required to 
be a <tt>place</tt> object. The <tt>updated</tt> and <tt>published</tt>
properties are required to be RFC 3339 Date-Times. The code will enforce those
rules fairly strictly by default.

Note: to set the "object" property, use the shortened alias "obj" ... this is to
prevent confusion with the object method that is used to create new object 
instances. Likewise, to set the "image" property, use the shortened alias "img".

For example, if you're setting geo-location data within an Activity and give
it an invalid latitude, an ArgumentError will be raised...

``` ruby
my_activity = activity {
  #... set other properies ...
  
  location {
    position {
      altitude 10.0
      longitude 128.23
      latitude 95.0       # whoops! .. => ArgumentError 
    }
  }
  
}
```

Such type checking is enforced throughout the model but it can be disabled by 
block or by property ... for instance:

``` ruby
my_activity = activity {
  #... set other properies ...
  
  location {
    position {
      altitude 10.0
      longitude 128.23
      latitude 95.0, LENIENT    # OK!!
    }
  }
  
}
```

or...

``` ruby
my_activity = activity {
  #... set other properies ...
  
  location {
    position {
      lenient
      altitude 10.0
      longitude 128.23
      latitude 95.0    # OK!!
    }
  }
  
}
```

The former method turns off validation for just the latitude
property; the latter turns it off for the entire location block.
Note, however, that the lenient setting is not inherited by child
blocks!

``` ruby
my_activity = activity {
  #... set other properies ...
  lenient
  location {
    position {
      altitude 10.0
      longitude 128.23
      latitude 95.0    # NOT OK!!! => ArgumentError
    }
  }
  
}
```

Note that in the examples given, the location object is automatically 
set to be a place object without us having to tell it. The code understands
the Activity Streams model and knows that <tt>location</tt> is always 
supposed to be a <tt>place</tt> object, so it just handles that for you
automatically. There are ways to override that, of course, but that would
just be silly.

So let's do something a bit more interesting... let's create a complete
Activity Stream document containing two activity objects

``` ruby
the_actor = person { display_name 'James' }
the_location = place { display_name 'My Home' }

s = collection {
  pretty
  total_items 2
  2.times {|x|
    item activity {
      title  "Item #{x}"
      verb   :post
      to     the_actor
      actor  the_actor
      obj note {
        content "Note #{x}"
      }
      self[:location] = the_location
    }
  }
}

STDOUT << s
```

Notice the different way of setting the location property? Within the block,
self refers to the ASObj being built. ASObj implements the []= operator to 
allow you to set properties directly on the underlying Hash. Note that setting
properties in this way completely bypasses the validation type checking, but 
since we already validated our place object when we created it, we don't need
to check it again. 

The JSON generated by the above is:

``` json
{
  "totalItems": 2,
  "items": [
    {
      "title": "Item 0",
      "verb": "post",
      "to": [
        {
          "objectType": "person",
          "displayName": "James"
        }
      ],
      "object": {
        "objectType": "note",
        "content": "Note 0"
      },
      "actor": {
        "objectType": "person",
        "displayName": "James"
      },
      "location": {
        "objectType": "place",
        "displayName": "My Home"
      }
    },
    {
      "title": "Item 1",
      "verb": "post",
      "to": [
        {
          "objectType": "person",
          "displayName": "James"
        }
      ],
      "object": {
        "objectType": "note",
        "content": "Note 1"
      },
      "actor": {
        "objectType": "person",
        "displayName": "James"
      },
      "location": {
        "objectType": "place",
        "displayName": "My Home"
      }
    }
  ]
}
```

In the previous example, we added items to the collection one at
a item using an iterator and the item function. We could, alternatively,
specify them as an array...

``` ruby
the_actor = person { display_name 'James' }
the_location = place { display_name 'My Home' }
the_items = 2.times.map {|x|
    activity {
      title  "Item #{x}"
      verb   :post
      to     the_actor
      actor  the_actor
      obj note {
        content "Note #{x}"
      }
      self[:location] = the_location
    }
  }

s = collection {
  pretty
  total_items the_items.length
  items the_items 
}

STDOUT << s
```

As mentioned previously, the code comes with support for all of the 
basic object types... but what if you want to use a non-standard type? 
For that, simply use the object() function...

``` ruby
m = object('http://example.org/foo/some/other/object/type') {
  pretty
  display_name "My Object Type"
  id 'http://example.org/foo'
}

STDOUT << m
```

Generates the following output:

``` json
{
  "objectType": "http://example.org/foo/some/other/object/type",
  "displayName": "My Object Type",
  "id": "http://example.org/foo"
}
```

Note that because all Activity Streams objects inherit a common set of
basic properties, property validation is still enforced within the 
custom object type. The "objectType" name MUST either be a simple 
label or an absolute IRI.

If your custom object type has specific type validation needs, then 
you can define your own validation Spec and plug it into the generator.
For example:

``` ruby
my_spec = spec {
  include ObjectSpec
  # our objects have a "foo" property whose value MUST be 'bar'
  def_string :foo do |v| v.eql? 'bar' end
}

add_spec :'http://example.org/foo/some/other/object/type', my_spec

# Then... if you create the object with that type...
m = object('http://example.org/foo/some/other/object/type') {
  pretty
  display_name "My Object Type"
  id 'http://example.org/foo'
  foo 'bar' ## this will pass validation!
  foo 'baz' ## this raises an ArgumentError!
}
```

Btw, note how the method <tt>foo</tt> just kind of magically appears. 
The language model here is extremely dynamic. I won't go into details on
how it works, however. A review of the source code should give you
an idea if you're curious.

That's it for now, will provide additional detail later on...

