class AddParentToVideoMigration < ActiveRecord::Migration
  def self.up
    add_column :videos, :parent, :integer
  end

  def self.down
    remove_column :videos, :parent
  end
end
