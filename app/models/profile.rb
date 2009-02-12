class Profile < ActiveRecord::Base
  # Uncomment if your using MySQL
  set_table_name 'profiles'
  
  # Uncomment if your using SimpleDB 
  # set_domain Panda::Config[:sdb_profiles_domain]
  # properties :title, :player, :container, :width, :height, :video_codec, :video_bitrate, :fps, :audio_codec, :audio_bitrate, :audio_sample_rate, :position, :updated_at, :created_at
end
