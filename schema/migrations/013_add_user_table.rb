class AddUserTable < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.column :login, :string
      t.column :crypted_password, :text
      t.column :salt, :text
      t.column :email, :string
      t.column :api_key, :string
      t.column :updated_at, :datetime
      t.column :created_at, :datetime
    end
  end

  def self.down
    drop_table :users
  end
end
