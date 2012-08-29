/**
 * Copyright 2012 James M Snell (jasnell@gmail.com)
 * 
 * Licensed under the Apache License, Version 2.0 (the "License"); 
 * you may not use this file except in compliance with the License. 
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, 
 * software distributed under the License is distributed on an 
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
 * either express or implied. See the License for the specific 
 * language governing permissions and limitations under the License.
 **/

/**
 * NOTE: This is still very much a work in progress. Stuff
 * can change at any time. Tread carefully.
 **/

var Throwables = {
  InvalidType : function() {}
};

var Predicates = {
  primitive : function(val) {
    var t = typeof val;
    return t === "string" || 
           t === "number" ||
           t === "boolean";
  },
  isType: function(val,type) {
    if (!val || !type) return true;
    if (Predicates.primitive(val) && val.constructor == type) return true;
    if (val instanceof type) return true;
    return false;
  },
  number : function(val) {
    return val instanceof Number || 
    (Predicates.primitive(val) && typeof val === "number");
  }
}

var Ranges = {
  closed : function(min,max) {
    return function(o) {
      if (!o || !Predicates.number(o)) return o;
      return Math.min(max,Math.max(min,o));
    }
  },
  nonNegative : function() {
    return function(o) {
      if (!o || !Predicates.number(o)) return o;
      return Math.max(0,o);
    }
  },
  types : function(type) {
    var ret = true;
    return function(o) {
      if (o instanceof Array) {
        var ret = new Array();
        for (n in o) {
          var m = (o[n] && o[n].get) ? o[n].get() : o[n];
          if (!Predicates.isType(m,type))
            throw new Throwables.InvalidType();
            ret.push(m);
        }
        return ret;
      } else if (!Predicates.isType(o,type))
        throw new Throwables.InvalidType(); 
        return o;
    }
  }
}

var Preconditions = {
  checkType : function(type,val) {
    if (!type || !val) return;
    if (!Predicates.isType(val,type))
      throw new Throwables.InvalidType();
  }
};

var AS = {
  make : function(props) {
    var obj = new AS.Builder(function() {});
    obj._init(AS._p.vocabs);
    if (props) obj._init(props);
    return obj;
  },
  obj : function(objectType, props) { 
    var obj = new AS.Builder(AS.Object);
    obj._init(AS._p.vocabs);
    obj._init(AS._p.obj);
    if (objectType) obj.objectType(objectType);
    if (props) obj._init(props);
    return obj;
  },
  link         : function() { return AS.obj("link",AS._p.link)},
  links        : function() { return AS.make(AS._p.links)},
  mediaLink    : function() { return AS.make(AS._p.mediaLink)},
  activity     : function() { return AS.obj("activity",AS._p.activity)},
  alert        : function() { return AS.obj("alert"); },
  application  : function() { return AS.obj("application"); },
  article      : function() { return AS.obj("article"); },
  audio        : function() { return AS.obj("audio",AS._p.av); },
  badge        : function() { return AS.obj("badge"); },
  bookmark     : function() { return AS.obj("bookmark",AS._p.bookmark); },
  collection   : function() { return AS.obj("collection",AS._p.collection); },
  comment      : function() { return AS.obj("comment"); },
  device       : function() { return AS.obj("device"); },
  event        : function() { return AS.obj("event",AS._p.event); },
  file         : function() { return AS.obj("file",AS._p.file); },
  game         : function() { return AS.obj("game"); },
  group        : function() { return AS.obj("group"); },
  image        : function() { return AS.obj("image",AS._p.image); },
  issue        : function() { return AS.obj("issue",AS._p.issue); },
  job          : function() { return AS.obj("job"); },
  note         : function() { return AS.obj("note"); },
  offer        : function() { return AS.obj("offer"); },
  organization : function() { return AS.obj("organization"); },
  page         : function() { return AS.obj("page"); },
  person       : function() { return AS.obj("person"); },
  place        : function() { return AS.obj("place",AS._p.place); },
  position     : function() { return AS.make(AS._p.position)},
  address      : function() { return AS.make(AS._p.address)},
  process      : function() { return AS.obj("process"); },
  product      : function() { return AS.obj("product",AS._p.image); },
  question     : function() { return AS.obj("question",AS._p.question); },
  review       : function() { return AS.obj("review"); },
  service      : function() { return AS.obj("service"); },
  task         : function() { return AS.obj("task",AS._p.activity)._init(AS._p.task); },
  video        : function() { return AS.obj("video",AS._p.av); }
}

AS._t = function(name,type,range) {
  return {
    name : name,
    type : type,
    range: range,
    toString : function() {
      return this.name;
    }
  };
}

AS.Object = function() {}
AS.Object.prototype = {
  write: function() {
    return JSON.stringify(this);
  }
}

AS.Builder = function(o) {
  this.o = o;
  this.obj = new AS.Object();
  this._init = function(properties) {
    var builder = this;
    if(properties.forEach)
      properties.forEach(function(p) {
        builder[p] = function(v) {
          builder.set(p,v,p.type,p.range);
          return builder;
        }
        if (p.type == Date) {
          builder[p + "Now"] = function() {
            return builder[p](new Date());
          }
        }
      });
    return builder;
  }
}
AS.Builder.prototype = {
  set: function(n,v,t,r) {
    if (!v) return this;
    var o = v instanceof AS.Builder ? v.get() : v;
    if (t) Preconditions.checkType(t,o);
    this.obj[n] = r?r(o):o;
    return this;
  },
  get: function() {
    return this.obj;
  },
  write: function() {
    return this.get().write();
  }
}

AS._p = {
    vocabs: [
      AS._t("dc",Object),
      AS._t("geojson",Object),
      AS._t("ld",Object),
      AS._t("links",Object),
      AS._t("odata",Object),
      AS._t("opengraph",Object),
      AS._t("schema_org",Object),
      AS._t("openSocial",Object)
    ],
    obj : [
      AS._t("attachments",Array,Ranges.types(AS.Object)),
      AS._t("author",AS.Object),
      AS._t("content",String),
      AS._t("displayName",String),
      AS._t("downstreamDuplicates",Array,Ranges.types(String)),
      AS._t("id",String),
      AS._t("image",AS.Object),
      AS._t("objectType",String),
      AS._t("published",Date),
      AS._t("summary",String),
      AS._t("updated",Date),
      AS._t("upstreamDuplicates",Array,Ranges.types(String)),
      AS._t("url",String),
      AS._t("startTime",Date),
      AS._t("endTime",Date),
      AS._t("rating",Number,Ranges.closed(0.0,5.0)),
      AS._t("location",AS.Object),
      AS._t("mood",AS.Object),
      AS._t("inReplyTo",Array,Ranges.types(AS.Object)),
      AS._t("source",AS.Object),
      AS._t("tags",Array,Ranges.types(AS.Object))],
    mediaLink : [
      AS._t("duration",Number,Ranges.nonNegative()),
      AS._t("height",Number,Ranges.nonNegative()),
      AS._t("url",String),
      AS._t("width",Number,Ranges.nonNegative())],
    collection : [
      AS._t("totalItems",Number,Ranges.nonNegative()),
      AS._t("items",Array,Ranges.types(AS.Object)),
      AS._t("url",String),
      AS._t("itemsAfter",Date),
      AS._t("itemsBefore",Date),
      AS._t("itemsPerPage",Number,Ranges.nonNegative()),
      AS._t("startIndex",Number,Ranges.nonNegative())],
    av : [
      AS._t("embedCode",String),
      AS._t("stream",AS.Object)],
    bookmark : [AS._t("targetUrl",String)],
    event : [
      AS._t("attendedBy",AS.Object), 
      AS._t("attending",AS.Object), 
      AS._t("invited",AS.Object), 
      AS._t("maybeAttending",AS.Object), 
      AS._t("notAttendedBy",AS.Object), 
      AS._t("notAttending",AS.Object)],
    file : [
      AS._t("fileUrl",String), 
      AS._t("mimeType",String)],
    image : [AS._t("fullImage",AS.Object)],
    issue : [AS._t("types",Array,Ranges.types(String))],
    place : [
      AS._t("position",Object), 
      AS._t("address",Object)],
    position: [
      AS._t("latitude",Number,Ranges.closed(-90.00,90.00)), 
      AS._t("longitude",Number,Ranges.closed(-180.00,+180.00)), 
      AS._t("altitude",Number)],
    address: [
      AS._t("formatted",String),
      AS._t("streetAddress",String),
      AS._t("locality",String),
      AS._t("region",String),
      AS._t("postalCode",String),
      AS._t("country",String)],
    question: [AS._t("options",Array,Ranges.types(AS.Object))],
    task: [
      AS._t("by",Date),
      AS._t("prerequisites",Array,Ranges.types(AS.Object)),
      AS._t("required",Array,Ranges.types(AS.Object)),
      AS._t("supersedes",Array,Ranges.types(AS.Object))],
    activity: [
      AS._t("actor",AS.Object),
      AS._t("content",String),
      AS._t("generator",AS.Object),
      AS._t("icon",AS.Object),
      AS._t("id",String),
      AS._t("object",AS.Object),
      AS._t("published",Date),
      AS._t("provider",AS.Object),
      AS._t("target",AS.Object),
      AS._t("title",String),
      AS._t("updated",Date),
      AS._t("url",String),
      AS._t("verb",String),
      AS._t("context",AS.Object),
      AS._t("result",AS.Object)],
    links : [
      AS._t("first",Array,Ranges.types(AS.Object)),
      AS._t("last",Array,Ranges.types(AS.Object)),
      AS._t("prev",Array,Ranges.types(AS.Object)),
      AS._t("previous",Array,Ranges.types(AS.Object)),
      AS._t("next",Array,Ranges.types(AS.Object)),
      AS._t("current",Array,Ranges.types(AS.Object)),
      AS._t("self",Array,Ranges.types(AS.Object)),
      AS._t("canonical",Array,Ranges.types(AS.Object)),
      AS._t("alternate",Array,Ranges.types(AS.Object))
    ],
    link : [
      AS._t("href",String),
      AS._t("hreflang",String),
      AS._t("title",String),
      AS._t("type",String)
    ]
  };
