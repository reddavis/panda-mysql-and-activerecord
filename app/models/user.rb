class User < ActiveRecord::Base
  # Uncomment if your using SimpleDB 
  # set_domain Panda::Config[:sdb_users_domain]
  # properties :password, :email, :salt, :crypted_password, :api_key, :updated_at, :created_at
  
  # Uncomment if your using MySQL  
  set_table_name 'users'
  
  attr_accessor :password
    
  def self.authenticate(login, password)
    unless  u = self.find_by_login(login) 
      return nil
    else
      puts "#{u.crypted_password} | #{encrypt(password, u.salt)}"
      u && (u.crypted_password == encrypt(password, u.salt)) ? u : nil
    end
  end

  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end
  
  def set_password(password)
    return if password.blank?
    salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{self.key}--")
    self.salt = salt
    self.crypted_password = self.class.encrypt(password, salt)
  end
  

end