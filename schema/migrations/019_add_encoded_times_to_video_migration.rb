class AddEncodedTimesToVideoMigration < ActiveRecord::Migration
  def self.up
    add_column :videos, :notification, :integer
    add_column :videos, :encoded_at, :datetime
    add_column :videos, :encoding_time, :datetime  
  end

  def self.down
    remove_column :videos, :notification
    remove_column :videos, :encoded_at
    remove_column :videos, :encoding_time
  end
end
