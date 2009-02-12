# This is just a quick fix!
# Note: could - model inherit ar then include ORM? it doesnt play nice the current way
class Connections
  attr_accessor :key, :attributes, :new_record
  
  # Connect it up
  
  def self.establish_simpledb_connection!(opts)
    @@connection = Amazon::SDB::Base.new(opts[:access_key_id], opts[:secret_access_key])
  end
  
  def self.establish_mysql_connection!
    @@connection = ActiveRecord::Base.establish_connection(
                                :adapter => "mysql",
                                :host => "localhost",
                                :username => "root",
                                :password => "",
                                :encoding => "utf8",
                                :database => "panda_production")
  end
end

module ORM
  
  #================ActiveRecord Changes=========================
  
  def self.included(base)
    base.extend ClassMethods
  end
  
  # SimpleDB wants a key, so a little hack, TODO: make better, simple, huh?
  def key
    self.id
  end
  
  def get(key)
    self.send(key)
  end
  
  include SimpleDB::InstanceMethods && ClassMethods.send(:include, SimpleDB::ClassMethods) if Panda::Config[:database] == :simpledb
  
  module ClassMethods
    def save
      updated_at = Time.now
      created_at = Time.now if @new_record == true
      super
      #@new_record = false
      #true
    end

    def query(query_options={})
      find(:all) if query_options.empty?    # Hack for 'query' from SimepleDB
    end
  end

end
  
  

module SimpleDB
  
  module ClassMethods
    attr_accessor :domain_name
    
    def connection; @@connection; end
    
    def domain
      @@connection.domain(self.domain_name)
    end

    def set_domain(d)
      self.domain_name = d
    end

    def properties(*props)
      props.each do |p|
        class_eval "def #{p}; self.get('#{p}'); end"
        class_eval "def #{p}=(v); self.put('#{p}', v); end"
      end
    end
    
    def create(*values)
      attributes = values.nil? ? Amazon::SDB::Multimap.new : Amazon::SDB::Multimap.new(*values) # TODO: Just pass values onto new
      self.new(nil, attributes)
    end

    def create!(*values)
      r = self.create(*values)
      r.save
      r
    end
    
    def find_by_login(key)
      find(key)
    end

    def find(key)
      self.new(key, self.domain.get_attributes(key).attributes, false)
    end

    # TODO: support next token
    def query(expr="", query_options={})
      result = []
      self.domain.query(query_options.merge({:expr => expr})).each do |i|
        result << self.new(i.key, i.attributes, false)
      end
      return result
    end
  end
  
  module InstanceMethods
    def initialize(key=nil, multimap_or_hash=nil, new_record=true)
      self.key = (key || UUID.new)
      self.attributes = multimap_or_hash.nil? ? Amazon::SDB::Multimap.new : (multimap_or_hash.kind_of?(Hash) ? Amazon::SDB::Multimap.new(multimap_or_hash) : multimap_or_hash)
      @new_record = new_record
    end

  
    def id
      self.key
    end
  
    def get(key)
      reload! if self.attributes.size == 0 and @new_record == false
      self.attributes.coerce(self.attributes.get(key))
    end
  
    def get_without_coerce(key)
      reload! if self.attributes.size == 0 # TOOD: add ` and @new_record == false`
      self.attributes.get(key)
    end
  
    def [](key)
      self.get(key)
    end

    def put(key, value)
      self.attributes.put(key, value, :replace => true)
    end
  
    def []=(key, value)
      self.put(key, value)
    end
  
    def set_attributes(attrs)
      attrs.each do |k,v|
        self.send(%(#{k}=),v)
      end
    end

    def save
      self.updated_at = Time.now
      self.created_at = Time.now if @new_record == true
      self.class.domain.put_attributes(self.key, self.attributes, :replace => :all)
      @new_record = false
      true
    end
  
    def destroy!
      self.class.domain.delete_attributes(self.key)
    end
  
    def reload!
      item = self.class.domain.get_attributes(self.key)
      self.attributes = item.attributes
    end
  end

end

ActiveRecord::Base.send(:include, ORM)