class Video < ActiveRecord::Base
  # Uncomment if your using SimpleDB 
  #set_domain Panda::Config[:sdb_videos_domain]
  #properties :filename, :original_filename, :parent, :status, :duration, :container, :width, :height, :video_codec, :video_bitrate, :fps, :audio_codec, :audio_bitrate, :audio_sample_rate, :profile, :profile_title, :player, :queued_at, :started_encoding_at, :encoding_time, :encoded_at, :last_notification_at, :notification, :updated_at, :created_at
  
  # Uncomment if your using MySQL  
  set_table_name 'videos'
  
  case Panda::Config[:database]
    when :simpledb
      include SimpleDBVideo::InstanceMethods
      class << self; include SimpleDBVideo::ClassMethods; end
    when :mysql
      include MySqlVideo::InstanceMethods
      class << self; include MySqlVideo::ClassMethods; end
  end
  

  
end