class AddOriginalfilenameVideosMigration < ActiveRecord::Migration
  def self.up
    add_column :videos, :original_filename, :string
  end

  def self.down
    remove_filename :videos, :original_filename
  end
end
