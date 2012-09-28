##############################################
# Author: James M Snell (jasnell@gmail.com)  #
# License: Apache v2.0                       #
#                                            #
# A simple Activity Streams implementation.  #
#   (forgive me... my ruby's a bit rusty)    #
#                                            #
# example use:                               #
# require 'activitystreams'                  #
# include ActivityStreams                    #
#                                            #
# STDOUT << activity {                       #
#   verb :post                               #
#   actor person {                           #
#     display_name 'James'                   #
#   }                                        #
#   object note {                            #
#     content 'This is a test'               #
#   }                                        #
# }                                          #
#                                            #
##############################################

require 'json'
require "time"
require 'addressable/uri'
require 'base64'
require 'zlib'
require 'i18n'
require 'mime/types'

class Hash
  # allows a Hash to be used in place of an 
  # ASObj ... we don't necessarily want a 
  # mixin on this, so just set a property  
  def __object_type= ot
    @object_type = ot
  end
  
  def __object_type
    @object_type
  end

end

class Object

  # Tests whether the method exists. Unlike the std method, however,
  # does not throw a NameError if it doesn't. Just returns false
  def method? sym
    method sym rescue false
  end
  
  # Tests to see if the Object is one of several possible types
  # like is_a? but accepting multiple arguments
  def one_of_type? *args
    args.any? {|x| is_a? x}
  end

end

module ActivityStreams
  
  # Provides a number of generally useful utilities methods
  module Matchers
    include Addressable
    
    # true if m validates as a isegment-nz-nc as defined by RFC 3987. 
    # The activity streams spec requires that verbs and object types 
    # MUST either be isegment-nz-nc or absolute IRI productions.
    def is_token? m
      return false if m == nil
      m = m.to_s
      (m =~ /^([a-zA-Z0-9\-\.\_\~]|\%[0-9a-fA-F]{2}|[\!\$\&\'\(\)\*\+\,\;\=\@])+$/) != nil
    end
    
    # true if m is parseable as an IRI and is absolute
    def is_absolute_iri? m
      URI.parse(m).absolute? rescue false
    end
    
    # true if m is a valid verb
    def is_verb? m
      is_token?(m) || is_absolute_iri?(m)
    end
    
    # true if m is a valid MIME Media Type
    def is_mime_type? m
      MIME::Type.new m rescue false
    end
    
    # true if m is a valid RFC 4646 Lang tag
    def is_lang_tag? m
      I18n::Locale::Tag::Rfc4646.tag m rescue false
    end
    
    # utility method providing the basic structure of validation 
    # checkers for the various fields...
    def checker &block
      ->(v) do
        raise ArgumentError unless block.call v
        v
      end
    end
    
    module_function :checker, :is_token?, :is_verb?, :is_absolute_iri?, :is_mime_type?, :is_lang_tag?

  end
  
  # Defines the basic functions for the Activity Streams DSL
  module Makers
    
    # Create a new object by copying another. 
    # A list of properties to omit from the new
    # copy can be provided a variable arguments.
    # For instance, if you have an existing activity
    # object and wish to copy everything but the 
    # current verb and actor properties, you could
    # call new_act = copy_from(old_act, :verb, :actor) { ... }
    def copy_from(other,*without,&block)
      ASObj.from other,*without,&block
    end
    
    # Create a new Activity Streams Object
    def object(object_type=nil,&block)
      ASObj.generate object_type,&block
    end
    
    # Create a new Media Link
    def media_link &block
      ASObj.generate :media_link,true,&block
    end
    
    # Create a new Collection Object
    def collection include_object_type=false, &block
      ASObj.generate :collection, !include_object_type, &block
    end
    
    # Create a new Activity Object
    def activity include_object_type=false, &block
      ASObj.generate :activity, !include_object_type, &block
    end
    
    # Utility method for returning the current time
    def now
      Time.now.utc
    end
    
    # For the remain object types from the Activity Streams Schema
    # iterate through them and create a factory method for each
    [ :alert,
      :application,
      :article,
      :audio,
      :badge,
      :binary,
      :bookmark,
      :comment,
      :device,
      :event,
      :file,
      :game,
      :group,
      :image,
      :issue,
      :job,
      :note,
      :offer,
      :organization,
      :page,
      :permission,
      :person,
      :place,
      :process,
      :product,
      :question,
      :review,
      :role,
      :service,
      :task,
      :team,
      :video
      ].each {|o|
        module_eval "def #{o}(&block) object :#{o}, &block end"
    }  
  end
  
  def checker &block
    Matchers.checker &block
  end
  
  module_function :checker
  
  include Makers, Matchers
  
  # Represents a basic Activity Streams Object...
  # Instances, once created, are immutable for 
  # all the core properties. The object maintains
  # an internal hash and performs basic input 
  # validation to ensure that the built object
  # conforms to the basic requirements of the 
  # Activity Streams specifications. Specific 
  # validation requirements are defined by the
  # Spec module associated with the object_type
  # specified for the ASObj instance
  class ASObj
    include Makers
    
    def initialize object_type=nil
      @_ = {}
      @_.__object_type = object_type
      @object_type = object_type  
      extend SPECS[object_type] || SPECS[nil]
      strict
    end
    
    # Puts this ASObj into lenient validation mode
    def lenient  
      @lenient = true   
    end
    
    # Puts this ASObj into strict validation mode
    def strict   
      @lenient = false  
    end
    
    # Tells this ASObj to generate formatted JSON output
    def pretty   
      @pretty = true    
    end
    
    # true if this ASObj has been configured to generate formatted JSON output
    def pretty?  
      @pretty || false  
    end
    
    # true if this ASObj is operating in lenient mode
    def lenient? 
      @lenient          
    end
    
    # true if this ASObj is operating in strict mode
    def strict?  
      !lenient?         
    end
    
    # the internal object type identifier for this ASObj
    def __object_type 
      @object_type 
    end
      
    # return a frozen copy of the internal hash
    def finish 
      @_.dup.freeze
    end
    
    # write this thing out, the param must repond to the << operator for appending
    def append_to out
      raise ArgumentError unless out.respond_to?:<<
      out << to_s
    end
    alias :>> append_to
    
    # force pretty printing
    def pretty_to out
      out << JSON.pretty_generate(@_)
    end
    
    # generates a copy of this object
    def copy_of *without, &block
      ASObj.from self, *without, &block
    end
    
    def to_s
      pretty? ? JSON.pretty_generate(@_) : @_.to_json
    end
    
    def [] k
      @_[send("alias_for_#{k}".to_sym) || k]
    end
    protected :[]  
    
    # Sets a value on the internal hash without any type checking
    # if v is an instance of ASObj, finish will be called
    # to get the frozen hash ... 
    def set k,v
      key = k.to_s.to_sym
      v = (v.is_a?(ASObj) ? v.finish : v) unless v == nil
      @_[key] = v unless v == nil
      @_.delete key if v == nil
    end
    alias :[]= :set 
    
    def freeze
      @_.freeze
      super
    end
    
    # Within the generator, any method call that has exactly one 
    # parameter will be turned into a member of the underlying hash
    def property m, *args, &block

      # Return nil if it's looking for an unknown alias_for_* method
      return nil if m =~ /^alias\_for\_.*/
      
      # Special magic... if an unknown ? method is called, it's treated 
      # as a check against the internal hash to see if the given field
      # has been set. For instance, priority? will check to see if the 
      # priority field has been set
      return @_.has_key?(m.to_s[0...-1].to_sym) if m =~ /.*\?/
      
      # Is it an unknown to_ method? e.g. to_ary ... if so, fall through to default
      if m =~ /^to\_.*/
        super
        return
      end
      
      # Once we get past the special cases, check to see if we have the 
      # expected number of arguments. 
      if !args.length.within?(1..2)
        raise NoMethodError
        return
      end
      
      # Now we start to figure out the exact value to set
      transform, alias_for, checker = [:transform_,:alias_for_,:check_].map {|x| "#{x}#{m}".to_sym }
      
      v = args[0]
      
      # First, if the value given is a ASObj, call finish on it
      v = (v.is_a?(ASObj) ? v.finish : v) unless v == nil
      
      # If it's an Enumerable, but not a Hash, convert to an Array using Map,
      # If each of the member items are ASObj's call finish.
      v = v.map {|i| i.is_a?(ASObj) ? i.finish : i } if v.is_a?(Enumerable) && !v.is_a?(Hash)
      
      # If the value is a Time object, let's make sure it's ISO 8601
      v = v.iso8601 if v.is_a? Time
           
      # Finally, do the object_type specific transform, if any 
      # note, this could potentially undo the previous checks if 
      # the transform provided by a given spec module isn't well
      # behaved. that's ok tho, we'll trust that it's doing the
      # right thing and just move on ... we're going to be validating
      # next anyway
      v = send transform, v if method? transform
      
      # Now let's do validation... unless lenient is set
      if !args[1] && strict?
        ok = method?(checker) ? send(checker,v) : missing_check(v)
        raise ArgumentError unless ok
      end
      m = send alias_for if method? alias_for
      @_[m] = v unless v == nil
      @_.delete m if v == nil
    end
    alias :method_missing :property
    
  end
  
  class << ASObj
    
    # Performs the actual work of creating an ASObj and executing
    # the associated block to build it up, then freezing the 
    # ASObj before returning it
    def generate object_type=nil, do_not_set_object_type=false, &block
      m = ASObj.new object_type
      m[:objectType] = object_type unless do_not_set_object_type
      m.instance_eval &block unless not block_given?
      m.freeze
    end
    
    # Creates a new ASObj by copying from another one
    def from other, *without, &block
      raise ArgumentError unless other.one_of_type?(ASObj,Hash)
      m = ASObj.new other.__object_type
      m.pretty if other.pretty?
      m.lenient if other.lenient?
      other.finish.each_pair {|k,y| m[k] = y unless without.include? k }
      m.instance_eval &block unless not block_given?
      m.freeze
    end
    
  end
  
  # The base module for all Validation Spec Modules.. these
  # define the requirements for the various Activity Streams
  # object types
  module Spec
    
    # by default, allow all values if a specific check hasn't been provided
    # Spec modules can override this behavior by defining their own missing_check
    def missing_check v
      true
    end
    
    # Defines the various utility methods used to build Spec modules
    module Defs
      
      # Maps an input symbol to a property name in the hash
      def def_alias sym, name
        define_method("alias_for_#{sym}".to_sym) {
          name
        } if name
        module_function "alias_for_#{sym}".to_sym
      end
      
      # Defines the method for validating the value of a 
      # specific property.
      def def_checker sym, &block
        sym = "check_#{sym}".to_sym
        define_method sym,&block
        module_function sym
      end
      
      # Defines a transform for the value of a specific property
      def def_transform sym, &block
        sym = "transform_#{sym}".to_sym
        if block_given?
          define_method sym,&block
        else
          define_method(sym) {|v|v} # just return self if no transform defined
        end
        module_function sym
      end
      
      # Mark def_alias, def_checker and def_transform as private
      # these should only be called from within the Defs module
      private :def_alias, :def_checker, :def_transform
      
      # Define a property as being an absolute IRI
      def def_absolute_iri sym, name=nil
        def_transform(sym) {|v| 
          next nil if v == nil
          Addressable::URI.parse(v)
        }
        def_checker(sym) { |v|
          # v must be an absolute IRI
          !v || is_absolute_iri?(v)
        }
        def_alias sym, name if name
      end
      
      # Define a property as being an ISO 8601 DateTime
      def def_date_time sym, name=nil
        def_transform(sym) {|v| 
          next v if v == nil || v.is_a?(Time)
          Time.parse(v.to_s) rescue v
        }
        def_checker(sym) { |v|
          # v must be parseable as a time
          next true if v == nil || v.is_a?(Time)
          Time.parse(v.to_s) rescue next false
          true
        }
        def_alias sym, name if name        
      end
      
      # Define a property as being an IRI ... does not have to be absolute
      def def_iri sym, name=nil
        def_transform(sym) {|v| 
          next nil if v == nill
          Addressable::URI.parse(v)}
        def_checker(sym) { |v|
          # v must be parseable as a URI
          !v || Addressable::URI.parse(v) rescue false
        }
        def_alias sym, name if name
      end
      
      # Define a property as being a string, an additional block
      # can be passed in to perform additional checking (e.g. regex matching, etc)
      def def_string sym, name=nil, &block
        def_transform(sym) {|v| 
          next nil if v == nil
          v.to_s 
        }
        def_checker(sym) { |v|
          # v will be converted to a string, then checked against the optional
          # block... if the block returns false, raise a validation error
          next true if v == nil
          next block.call(v.to_s) if block_given?
          true
        }
        def_alias sym, name if name
      end
      
      # Define a property as being an ASObj.
      def def_object sym, object_type=nil, name=nil
        def_transform(sym)
        def_checker(sym) { |v|
          next true if v == nil
          # v must be an instance of the given object_type
          if object_type
            next false if v.__object_type != object_type
          end
          # right now this is pretty strict... we only allow Hash or ASObj 
          # instances to be passed. TODO: see if we can relax this to enable 
          # more flexible duck typing ...
          v.one_of_type? Hash, ASObj
        }
        def_alias sym, name if name
        def_property(sym, object_type, name) if object_type
      end
      
      # Define a property as being an Array of ASObj's
      def def_object_array sym, object_type=nil, name=nil
        def_alias sym, name if name
        def_transform(sym) {|v|
          next nil if v == nil
          orig = self[sym]
          if v.is_a?(Array)
            next orig ? orig + v : v
          end
          orig ? orig << v : [v] 
        }
        def_checker(sym) { |v|
          next true if v == nil
          # v must be either an array or enumerable and each item
          # must be either a Hash or ASObj that matches the given
          # object_type, if any
          next false unless (v.one_of_type?(Array, Enumerable) && !v.is_a?(Hash))
          v.each {|x| 
            return false unless x.one_of_type? ASObj, Hash
            return false if (object_type && x.__object_type != object_type)
          }
          true
        }
      end
      
      # Define a property as being an Array of Strings, an additional
      # block can be passed to perform additional checking
      def def_string_array sym, name=nil, &block
        def_transform(sym) {|v|
          next nil if v == nil
          orig = self[sym]
          if v.one_of_type? Array, Enumerable
            add = v.map {|x| x.to_s}
            next orig ? orig + add : add
          end
          orig ? orig << v.to_s : [v.to_s]
        }
        def_checker(sym) { |v|
          next true if v == nil
          next false unless (v.one_of_type?(Array, Enumerable) && !v.is_a?(Hash))
          v.each {|x| 
            return false unless block.call(x) 
          } if block_given?
          true
        }
        def_alias sym, name if name
      end
      
      def def_boolean sym, name=nil
        def_transform(sym) {|v|
          next false if v == nil
          v ? true : false
        }
        def_checker(sym) { |v|
          v.one_of_type? TrueClass, FalseClass
        }
        def_alias sym, name if name
        
        module_eval %Q/def #{sym}() property(:'#{sym}', true) end/
        module_eval %Q/def not_#{sym}() property(:'#{sym}', false) end/
      end
      
      # Define a property as being a Numeric
      def def_numeric sym, name=nil, &block
        def_checker(sym) { |v|
          next true if v == nil
          return false unless v.is_a? Numeric
          if block_given?
            next false unless block.call v
          end
          true
        }
        def_alias sym, name if name
      end
      
      # Define a property as being a non-negative fixnum
      def def_non_negative_int sym, name=nil
        def_numeric(sym, name) {|v| 
          next false unless (v.is_a?(Fixnum) && v >= 0)
          true
        }
      end
      
      # Define a property as being a float with a bounded range
      def def_bound_float sym, range, name=nil
        def_numeric(sym, name) {|v|
          next false if (range.respond_to?(:include?) && !range.include?(v))
          true
        }
      end
      
      def def_property sym, type=nil, name=nil
        sym = sym.to_s
        module_eval %Q/
          def #{sym} &block
            self[:#{name || sym}] = ASObj.generate(:#{type},true,&block)
          end
        /
      end
      private :def_property
    end
    
    # Ensure the the Defs module is included in all spec modules...
    extend Defs
    def self.included(other)
      other.extend Defs
    end
    
  end
    
  # The base spec for all ASObj's
  module ObjectSpec 
    include Spec
    def_string       :content
    def_string       :display_name, :displayName
    def_string       :object_type, :objectType
    def_string       :summary
    def_string       :aka, :alias
    def_date_time    :updated
    def_date_time    :published
    def_date_time    :start_time, :'start-time'
    def_date_time    :end_time, :'end-time'
    def_object       :links, :links
    def_object       :author
    def_object       :img, :media_link, :image
    def_object       :source
    def_object       :location, :place
    def_object       :mood, :mood
    def_bound_float  :rating, 0.0..5.0
    def_absolute_iri :id
    def_iri          :url
    def_object_array :attachments
    def_object_array :in_reply_to, nil, :inReplyTo

    check = ->(x){ is_absolute_iri? x }
    def_string_array :downstream_duplicates, :downstreamDuplicates, &check
    def_string_array :upstream_duplicates, :upstreamDuplicates, &check

    def attachment m, &block
      property :attachments, m, &block
    end
    
    def downstream_duplicate m, &block
      property :downstream_duplicates, m, &block
    end
    
    def upstream_duplicate m, &block
      property :upstream_duplicates, m, &block
    end

    # Basic support for external vocabularies..
    # Developers will have to register their own
    # spec modules for these, but we at least 
    # provide the constructor methods
    def ext_vocab sym, &block
      self[sym] = ASObj.generate(sym,true,&block)
    end
    [:schema_org, :ld, :dc, :odata, :opengraph].each do |x|
      module_eval "def #{x}(&block) ext_vocab(:#{x},&block) end"
    end
    
    # ensure that all spec object include the Defs module...
    include Defs
    def self.included(other)
      other.extend Defs
      other.module_exec {
        def self.included(o)
          o.extend Defs
        end
      }
    end
        
  end

  module ActivitySpec 
    include ObjectSpec
    def_string       :verb do |v| is_verb? v end
    def_string       :content
    def_string       :title
    def_object       :icon, :media_link
    def_object       :generator
    def_object       :actor
    def_object       :target
    def_object       :obj, nil, :object
    def_object       :provider
    def_object       :context
    def_object       :result
    def_object_array :to
    def_object_array :cc
    def_object_array :bto
    def_object_array :bcc
    def_bound_float  :priority, 0.0..1.0    
  end
  
  module MediaLinkSpec 
    include Spec
    def_absolute_iri     :url
    def_non_negative_int :duration
    def_non_negative_int :width
    def_non_negative_int :height
  end
  
  module MoodSpec 
    include Spec
    def_string :display_name, :displayName
    def_object :img, :mediaLink, :image
  end
  
  module AddressSpec 
    include Spec
    def_string :formatted
    def_string :street_address, :streetAddress
    def_string :locality
    def_string :region
    def_string :postal_code, :postalCode
    def_string :country
  end
  
  module PositionSpec
    include Spec
    def_numeric     :altitude
    def_bound_float :longitude, -180.00..180.00
    def_bound_float :latitude, -90.00..90.00
  end
  
  module PlaceSpec
    include ObjectSpec
    def_object :position, :position
    def_object :address, :address  
  end
  
  module CollectionSpec
    include ObjectSpec
    def_date_time        :items_after, :itemsAfter
    def_date_time        :items_before, :itemsBefore
    def_non_negative_int :items_per_page, :itemsPerPage
    def_non_negative_int :start_index, :startIndex
    def_non_negative_int :total_items, :totalItems
    def_object_array     :items
    def_string_array     :object_types, :objectTypes
    
    def item m, &block
      property :items, m, &block
    end
    
  end
  
  module AVSpec
    include ObjectSpec
    def_string :embed_code, :embedCode
    def_object :stream, :media_link    
  end
  
  module FileSpec
    include ObjectSpec
    def_string       :mime_type, :mimeType do |x| is_mime_type? x end
    def_string       :md5
    def_absolute_iri :file_url,  :fileUrl
  end
  
  module BinarySpec
    include FileSpec
    def_string           :compression
    def_string           :data
    def_non_negative_int :length
    
    def init_hasher hash
      require 'Digest'
      hash_name = "#{hash.to_s.upcase}"
      Digest.module_eval "#{hash_name}.new"
    rescue LoadError
      raise ArgumentError.new("Invalid Hash [#{hash}]")
    end
     
    def do_compression data, compress, level
      case compress 
        when nil then return data
        when :deflate
          data = Zlib::Deflate.deflate(data,level)
        when :gzip 
          data = IO.pipe { |r,w|
            gzip = Zlib::GzipWriter.new(w,level)
            gzip.write data
            gzip.close 
            r.read
          }
        else raise ArgumentError
      end
      data
    end
    
    private :init_hasher, :do_compression
     
    # Specify the data for the Binary object. The src must either be an IO object
    # or a string containing a file path and name or an ArgumentError will be raised. 
    # Deflate compression by default, level 9, pass in :gzip to use Gzip compression 
    # or nil to disable compression entirely. The length and compression fields will 
    # automatically be set. This method will NOT close the src IO when it's done, you'll
    # need to handle that yourself. Currently this doesn't do any error handling
    # on the IO read. Also, it currently reads the entire IO stream first, 
    # buffers it into memory, then compresses before base64 encoding...
    def data(src, options={:compress=>:deflate, :level=>9, :hash=>:md5})
      compress = options.fetch :compress, :deflate
      level    = options.fetch :level, 9
      hash     = options.fetch :hash, :md5
      
      if src.is_a? String
        File.open(src, 'r') {|f| data f, options }
      else
        raise ArgumentError unless src.is_a? IO
      
        # Optionally generate a hash over the data as it is read
        if hash 
          hasher = init_hasher(hash)
          d = src.read {|block| hasher.update block }
          self[hash] = hasher.hexdigest
        else
          d = src.read
        end
      
        # Set the uncompressed length of the data in octets
        self[:length] = d.length
      
        # Apply compression if necessary
        if compress
          d = do_compression d, compress, level
          self[:compress] = compress
        end
      
        # Set the data
        self[:data] = Base64.urlsafe_encode64(d)
      end
    end
        
  end
  
  module EventSpec
    include ObjectSpec
    def_object :attended_by,     :collection, :attendedBy
    def_object :attending,       :collection
    def_object :invited,         :collection
    def_object :maybe_attending, :collection, :maybeAttending
    def_object :not_attended_by, :collection, :notAttendedBy
    def_object :not_attending,   :collection, :notAttending
  end
  
  module IssueSpec
    include ObjectSpec
    def_string_array(:types) {|v| is_absolute_iri? v }
    
    def type m, &block
      property :types, m, &block
    end
  end
  
  module PermissionsSpec
    include ObjectSpec
    def_object       :scope
    def_string_array :actions
    
    def action m, &block
      property :actions, m, &block
    end
  end
  
  module RGSpec # For "role" and "group" objects
    include ObjectSpec
    def_object :members, :collection
  end
  
  module TaskSpec
    include ActivitySpec
    def_date_time    :by
    def_object_array :prerequisites, :task
    def_object_array :supersedes, :task
    
    def prerequisite m, &block
      property :prerequisites, m, &block
    end
    
    def supersede m, &block
      property :supersedes, m, &block
    end
    
  end
  
  module ImageSpec
    include ObjectSpec
    def_object :full_image, :media_link, :fullImage
  end
  
  module BookmarkSpec
    include ObjectSpec
    def_absolute_iri :target_url, :targetUrl
  end
  
  module LinkSpec
    include ObjectSpec
    def_absolute_iri :href
    def_string       :title
    def_string       :hreflang do |x| is_lang_tag? x end # must be a RFC 4646 tag
    def_string       :type do |x| is_mime_type? x end # must be a valid MIME Media Type
  end
  
  module LinksSpec
    include Spec
    # Require that all properties on the Links spec are link objects
    def missing_check v 
      v.one_of_type? Hash, LinkSpec
    end
    
    def link rel, include_object_type=false, &block
      self[rel.to_sym] = ASObj.generate :link, !include_object_type, &block
    end
    
    def link_with_object_type rel, &block
      link rel, true, &block
    end
  end
  
  # Collect the various Specs and map to their respective object types
  SPECS = {
    nil         => ObjectSpec,
    :activity   => ActivitySpec,
    :media_link => MediaLinkSpec,
    :mood       => MoodSpec,
    :address    => AddressSpec,
    :place      => PlaceSpec,
    :position   => PositionSpec,
    :collection => CollectionSpec,
    :audio      => AVSpec,
    :video      => AVSpec,
    :binary     => BinarySpec,
    :file       => FileSpec,
    :event      => EventSpec,
    :issue      => IssueSpec,
    :permission => PermissionsSpec,
    :role       => RGSpec,
    :group      => RGSpec,
    :task       => TaskSpec,
    :product    => ImageSpec,
    :image      => ImageSpec,
    :link       => LinkSpec,
    :links      => LinksSpec
  }
  
  # override or add a new spec... be careful here.. the existing 
  # spec definitions can be overridden
  def add_spec sym, spec 
    SPECS[sym] = spec
  end
  
  # create a new Spec module
  def spec *specs, &block
    o = Module.new.extend Spec, Spec::Defs, *specs
    o.module_exec &block
    o
  end
  
  # create a new Spec module based on ObjectSpec
  def object_spec *specs, &block
    spec ObjectSpec, *specs, &block
  end
    
  # define the template method as an alias to lambda
  alias :template :lambda
    
  module_function :add_spec, :spec, :object_spec
  
  # syntactic sugar
  LENIENT, STRICT = true, false
  
  # basic priorities...
  HIGHEST, HIGH, MEDIUM, NORMAL, LOW, LOWEST, NONE = 1.0, 0.75, 0.50, 0.50, 0.25, 0.00, 0.00
  
  # Provide additional , currently experimental object types and features
  # These may change at any time...
  module Experimental 
    extend ActivityStreams 
    
    ANY = :'*'
    
    def verb_object &block
      ASObj.generate :verb,false,&block
    end
    
    # Experimental!! May change.. see http://goo.gl/x2XZl
    module VerbSpec
      include ObjectSpec
      verb_check = ->(x){is_verb? x}
      def_string :value, &verb_check
      def_string_array :hypernyms, &verb_check
      def_string_array :synonyms, &verb_check
      def_object_array :objects, :object_combination
    
      def combo &block
        ASObj.generate :object_combination,true,&block
      end 
    
      def hypernym x
        property :hypernyms, x
      end
    
      def synonym x
        property :synonyms, x
      end
    
      def obj x, &block
        property :foos, x, &block
      end
    end
  
    module ObjectCombinationSpec
      include Spec
      def_string :actor
      def_string :obj, :object
      def_string :target
      def_boolean :target_required, :targetRequired
      def_object :templates, :object_templates

      def target t, required=false, &block
        property :target, t, &block
        target_required if required
      end

    end 
  
    module ObjectTemplatesSpec
      include Spec
      def missing_checker v
        v.is_a? String
      end
    end
    
    add_spec :verb, VerbSpec
    add_spec :object_combination, ObjectCombinationSpec
    add_spec :object_templates, ObjectTemplatesSpec

  end # END EXPERIMENTAL MODULE
    
end

# some syntactic sugar for Fixnums... useful for 
# working with Time .. e.g. updated now - 1.week #updated one week ago
class Fixnum
  
  # true if this number is within the given range
  def within? r
    raise ArgumentError if not r.is_a?Range
    r.include? self
  end unless method_defined?(:within?)
  
  # treats the fixnum as a representation of a number
  # of milliseconds, returns the approximate total number 
  # of seconds represented e.g. 1000.milliseconds => 1
  # fractional seconds are truncated (rounded down)
  def milliseconds
    self / 1000
  end unless method_defined?(:milliseconds)
  
  # treats the fixnum as a representation of a number
  # of seconds
  def seconds
    self
  end unless method_defined?(:seconds)
  
  # treats the fixnum as a representation of a
  # number of minutes and returns the total number
  # of seconds represented.. e.g. 2.minutes => 120,
  # 3.minutes => 180
  def minutes
    seconds * 60
  end unless method_defined?(:minutes)
  
  # treats the fixnum as a representation of a 
  # number of hours and returns the total number
  # of seconds represented.. e.g. 2.hours => 7200
  def hours
    minutes * 60
  end unless method_defined?(:hours)

  # treats the fixnum as a representation of a
  # number of days and returns the total number
  # of seconds represented.. e.g. 2.days => 172800
  def days
    hours * 24
  end unless method_defined?(:days)

  # treats the fixnum as a representatin of a 
  # number of weeks and returns the total number
  # of seconds represented.. e.g. 2.weeks => 1209600 
  def weeks
    days * 7
  end unless method_defined?(:weeks)
  
  alias second seconds unless method_defined?(:second)
  alias minute minutes unless method_defined?(:minute)
  alias hour hours unless method_defined?(:hour)
  alias day days unless method_defined?(:day)
  alias week weeks unless method_defined?(:week)
  
end
