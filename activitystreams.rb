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

class Hash
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
  def one_of_type? sym, *rest
    [sym,*rest].each {|x|
      return true if is_a? x
    }
    false
  end
end

module ActivityStreams
  
  module Matchers
    include Addressable
    def is_token? m
      return false if m == nil
      m = m.to_s
      (m =~ /^([a-zA-Z0-9\-\.\_\~]|\%[0-9a-fA-F]{2}|[\!\$\&\'\(\)\*\+\,\;\=])+$/) != nil
    end
    def is_verb? m
      return true if is_token? m
      URI.parse(m).absolute?
    end
    def checker &block
      lambda {|v|
        raise ArgumentError unless block.call v
        v
      }
    end
    module_function :checker, :is_token?, :is_verb?
  end
  
  module Makers
    def copy_from(other,&block)
      ASObj.from other,&block
    end
    def object(object_type=nil,&block)
      ASObj.generate object_type,&block
    end
    def media_link &block
      ASObj.generate :media_link,true,&block
    end
    def collection include_object_type=false, &block
      ASObj.generate :collection, !include_object_type, &block
    end
    def activity include_object_type=false, &block
      ASObj.generate :activity, !include_object_type, &block
    end
    def now
      Time.now.utc
    end
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
  
  class ASObj
    include Makers
    def initialize object_type=nil
      @_ = {}
      @_.__object_type = object_type
      @object_type = object_type
      extend SPECS[object_type] ? SPECS[object_type] : SPECS[nil]
      strict
    end
    def lenient
      @lenient = true
    end
    def strict
      @lenient = false
    end
    def pretty
      @pretty = true
    end
    def pretty?
      @pretty || false
    end
    def lenient?
      @lenient
    end
    def strict?
      !lenient?
    end
    def __object_type
      @object_type
    end
    # return a frozen copy of the internal hash
    def finish
      @_.dup.freeze
    end
    # write this thing out
    def append_to out
      raise ArgumentError unless out.respond_to?:<<
      out << to_s
    end
    alias :>> append_to
    def to_s
      pretty? ? JSON.pretty_generate(@_) : @_.to_json
    end
    def [] k
      @_[send("alias_for_#{k}".to_sym) || k]
    end
    protected :[]  
    
    # Sets a value on the internal hash without any type checking
    # if the value is an instance of ASObj, finish will be called
    # to get the frozen hash ...
    def []=k,v
      key = k.to_s.to_sym
      v = v.is_a?(ASObj) ? v.finish : v unless v == nil
      @_[key] = v unless v == nil
      @_.delete key if v == nil
    end
    alias :set :[]=
    def freeze
      @_.freeze
      super
    end
    
    # Within the generator, any method call that has exactly one 
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
      transform, alias_for, checker = [:transform_,:alias_for_,:check_].map {|x| 
        "#{x}#{m}".to_sym }
      
      # First, if the value given is a ASObj, call finish on it
      v = (args[0].is_a?(ASObj) ? args[0].finish : args[0]) unless not args[0]
      
      # If it's an Enumerable, but not a Hash, convert to an Array using Map,
      # If each of the member items are ASObj's call finish.
      v = v.map {|i| i.is_a?(ASObj) ? i.finish : i } if (v.is_a?(Enumerable) && !v.is_a?(Hash))
      
      # If the value is a Time object, let's make sure it's ISO 8601
      v = v.iso8601 if v.is_a? Time
      
      # Finally, do the object_type specific transform, if any 
      v = method?(transform) ? send(transform, v) : v
      
      # Now let's do validation... unless lenient is set
      if !args[1] && strict?
        raise ArgumentError unless (method?(checker) ? send(checker,v) : missing_check(v))
      end
      m = send alias_for if method? alias_for
      @_[m] = v unless v == nil
      @_.delete m if v == nil
    end
    alias :method_missing :property
  end
  
  class << ASObj
    def generate object_type=nil, do_not_set_object_type=false, &block
      m = ASObj.new object_type
      m[:objectType] = object_type unless do_not_set_object_type
      m.instance_eval &block unless not block_given?
      m.freeze
    end
    
    def from other, &block
      raise ArgumentError unless other.one_of_type?(ASObj,Hash)
      m = ASObj.new other.__object_type
      other.finish.each_pair {|k,y| m[k] = y }
      m.instance_eval &block unless not block_given?
      m.freeze
    end
    
  end
  
  
  module Spec
    # by default, allow all values if a specific check hasn't been provided
    # Spec modules can override this behavior by defining their own missing_check
    def missing_check v
      true
    end
    
    # Defines the various utility methods used to build Spec modules
    module Defs
      def def_alias sym, name
        define_method("alias_for_#{sym}".to_sym) {
          name
        } if name
        module_function "alias_for_#{sym}".to_sym
      end
      def def_checker sym, &block
        sym = "check_#{sym}".to_sym
        define_method sym,&block
        module_function sym
      end
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
          next true if v == nil
          Addressable::URI.parse(v).absolute? rescue false
        }
        def_alias sym, name if name
      end
      
      # Define a property as being an ISO 8601 DateTime
      def def_date_time sym, name=nil
        def_transform(sym) {|v| 
          next nil if v == nil
          next v if v.is_a?Time
          Time.parse(v.to_s) rescue v
        }
        def_checker(sym) { |v|
          # v must be parseable as a time
          next true if v == nil
          next true if v.is_a?Time
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
          next true if v == nil
          # v must be parseable as a URI
          Addressable::URI.parse(v) rescue false
        }
        def_alias sym, name if name
      end
      
      # Define a property as being a string, and additional block
      # can be passed in to perform additional checking (e.g. regex matching, etc)
      def def_string sym, name=nil, &block
        def_transform(sym) {|v| 
          next nil if v == nil
          v.to_s }
        def_checker(sym) { |v|
          # v will be converted to a string, then checked against the optional
          # block... if the block returns false, raise a validation error
          next true if v == nil
          v = v.to_s
          next block.call(v) if block_given?
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
            return false if (object_type && v.__object_type != object_type)
            return false unless x.one_of_type? ASObj, Hash
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
          next false unless v.one_of_type? Array, Enumerable
          true
        }
        def_alias sym, name if name
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
      
      # Define a property as being a non-negative integer
      def def_non_negative_int sym, name=nil
        def_numeric(sym, name) {|v| 
          next false unless v.is_a? Integer 
          next false unless v >= 0
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
        suffix = sym[-1] if sym[-1] == '_'
        sym = sym[0...-1] if sym[-1] == '_'
        module_eval %Q/
          def #{sym}#{(suffix ? suffix : '')} &block
            self[:#{name ? name : sym}] = ASObj.generate(:#{type},true,&block)
          end
        /
      end
      private :def_property
    end
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
    def_string_array(:downstream_duplicates, :downstreamDuplicates) {|x| Addressable::URI.parse(x).absolute? }
    def_string_array(:upstream_duplicates, :upstreamDuplicates) {|x| Addressable::URI.parse(x).absolute? }

    def ext_vocab sym, &block
      self[sym] = ASObj.generate(sym,true,&block)
    end
    [:schema_org, :ld, :dc, :odata, :opengraph].each do |x|
      module_eval "def #{x}(&block) ext_vocab(:#{x},&block) end"
    end
    
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
    def_bound_float :longitude, -180.00, 180.00
    def_bound_float :latitude, -90.00, +90.00
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
  end
  
  module AVSpec
    include ObjectSpec
    def_string :embed_code, :embedCode
    def_object :stream, :media_link    
  end
  
  module FileSpec
    include ObjectSpec
    def_string       :mime_type, :mimeType
    def_string       :md5
    def_absolute_iri :file_url, :fileUrl
  end
  
  module BinarySpec
    include FileSpec
    def_string           :compression
    def_string           :data
    def_non_negative_int :length
  end
  
  module EventSpec
    include ObjectSpec
    def_object :attended_by, :collection, :attendedBy
    def_object :attending, :collection, :attending
    def_object :invited, :collection
    def_object :maybe_attending, :collection, :maybeAttending
    def_object :not_attended_by, :collection, :notAttendedBy
    def_object :not_attending, :collection, :notAttending
  end
  
  module IssueSpec
    include ObjectSpec
    def_string_array(:types) {|v| Addressable::URI.parse(v).absolute? }
  end
  
  module PermissionsSpec
    include ObjectSpec
    def_object       :scope
    def_string_array :actions
  end
  
  module RGSpec
    include ObjectSpec
    def_object :members, :collection
  end
  
  module TaskSpec
    include ActivitySpec
    def_date_time    :by
    def_object_array :prerequisites, :task
    def_object_array :supersedes, :task
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
    def_string       :hreflang # TODO: Need to validate language tags
    def_string       :type     # TODO: Need to validate mime types
  end
  
  module LinksSpec
    include Spec
    # Require that all properties on the Links spec are link objects
    def missing_check v 
      v.is_one_if? Hash, LinkSpec
    end
    
    def link rel, include_object_type=false, &block
      self[rel.to_sym] = ASObj.generate(:link,!include_object_type,&block)
    end
    
    def link_with_object_type rel, &block
      link rel,true,&block
    end
  end
  
  SPECS = {
    nil => ObjectSpec,
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
  
  def spec &block
    o = Module.new.extend(Spec, Spec::Defs)
    o.module_exec &block
    o
  end
  module_function :add_spec, :spec
  
  # syntactic sugar
  LENIENT, STRICT = true, false
  
end

# some syntactic sugar for Integers
class Integer
  def within? r
    raise ArgumentError if not r.is_a?Range
    r.include? self
  end unless method_defined?(:within?)
  def seconds
    self
  end unless method_defined?(:seconds)
  def minutes
    self * 60
  end unless method_defined?(:minutes)
  def hours
    self * 60 * 60
  end unless method_defined?(:hours)
  alias second seconds unless method_defined?(:second)
  alias minute minutes unless method_defined?(:minute)
  alias hour hours unless method_defined?(:hour)
end