require 'panda'

Panda::Config.use do |p|
  p[:database]               = :mysql 
  
  p[:account_name]           = "Green Thing"
  p[:api_key]                = "this-is-so-extremly-cool-yes-yup"
  p[:upload_redirect_url]    = "http://localhost:4000/videos/$id/done"
  p[:state_update_url]       = "http://localhost:3000/stories/$id/status"
  p[:videos_domain]          = "s3.amazonaws.com/videos.panda.com/"
  p[:tmp_video_dir]          = Merb.root / "videos"
  
  p[:access_key_id]          = "044TB9MYBVF9XEPFZZ02"
  p[:secret_access_key]      = "GhBtHLjm0rcX7fweTRF17XWNQjCdsn1ArsZYr+dk"
  p[:s3_videos_bucket]       = "videos.panda.com"
  p[:sdb_videos_domain]      = "panda_videos"
  p[:sdb_users_domain]       = "panda_users"
  p[:sdb_profiles_domain]    = "panda_profiles"
  
  p[:thumbnail_height_constrain] = 125
  
  p[:notification_retries] = 6 # How many times should a failed notification be retried?
  p[:notification_frequency] = 2 # How many
  p[:notification_email]     = "me@mydomain.com" # Where notifications get sent to
  p[:noreply_from]     = "no-reply@pandastream.com" # Where notifications come from
end