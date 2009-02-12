class AddProfileToVideoMigration < ActiveRecord::Migration
  def self.up
    add_column :videos, :profile, :string
    add_column :videos, :player, :string
    add_column :videos, :audio_bitrate, :integer
  end

  def self.down
    remove_column :videos, :profile
    remove_column :videos, :player
    remove_column :videos, :audio_bitrate
  end
end
