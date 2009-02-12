$LOAD_PATH.unshift(Merb.root / "lib")

dependencies 'activesupport', 'merb-assets', 'merb-mailer', 'merb_helpers', 'uuid', 'amazon_sdb', 'rvideo'

use_orm :activerecord
use_test :rspec
use_template_engine :erb

require "config" / "panda_init"

#dependencies 'rack'

require 'activerecord'

# ORM require. Simpledb Mysql
require 'inline'
require 'lib/to_simple_xml'
require 'lib/simple_db'
require 'lib/retryable' 
require 'lib/panda'
#require 'lib/gd_resize'
require 'lib/map_to_hash'
require 'lib/spec_eql_hash'
require 'lib/error_sender'
require 'lib/rog'
require 'lib/orm_setup'

require 'aws/s3'


mysql_depen = File.join(Merb.root, "lib", "*_modules", "*.rb")
Dir.glob(mysql_depen).each {|file| require file}
 
Merb::Config.use do |c|
  c[:use_mutex] = false
  c[:session_store] = 'cookie'  # can also be 'memory', 'memcache', 'container', 'datamapper
  
  # cookie session store configuration
  c[:session_secret_key]  = 'b1de740f4dd2155b26c4025b076e42f12315c3da'  # required for cookie session store
  # c[:session_id_key] = '_session_id' # cookie session id key, defaults to "_session_id"
end
 
Merb::BootLoader.before_app_loads do
  # This will get executed after dependencies have been loaded but before your app's classes have loaded.
end
 
Merb::BootLoader.after_app_loads do
  unless Merb.environment == "test"
    require "config" / "aws"
    require "config" / "mailer" # If you want notification and encoding errors to be sent to you as well as logged
  end

end