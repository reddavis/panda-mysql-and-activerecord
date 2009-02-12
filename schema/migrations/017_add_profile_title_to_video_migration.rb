class AddProfileTitleToVideoMigration < ActiveRecord::Migration
  def self.up
    add_column :videos, :profile_title, :string
  end

  def self.down
    remove_column :videos, :profile_title
  end
end
