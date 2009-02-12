class AddProfileTableMigration < ActiveRecord::Migration
  def self.up
    create_table :profiles do |t|
      t.column :title, :string
      t.column :player, :string
      t.column :container, :string
      t.column :width, :integer
      t.column :height, :integer
      t.column :video_codec, :string
      t.column :video_bitrate, :integer
      t.column :fps, :integer
      t.column :audio_codec, :string
      t.column :audio_bitrate, :integer
      t.column :audio_sample_rate, :integer
      t.column :position, :integer
      t.column :updated_at, :datetime
      t.column :created_at, :datetime
    end
  end

  def self.down
    drop_table :profiles
  end
end


