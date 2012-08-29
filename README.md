js.strea.ms
===========

A simple JavaScript Activity Streams implementation.

Example:

<pre>
var as = 
  AS.activity()
    .actor(AS.person().displayName("James"))
    .verb("post")
    .object(AS.note().content("test"))
    .links(AS.links().alternate([AS.link().href("http://example.org")]).set("canonical",[]))
    .get();

print(as.write());
</pre>

More details to be added later...