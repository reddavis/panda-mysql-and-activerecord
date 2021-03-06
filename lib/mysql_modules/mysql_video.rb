module MySqlVideo
  # Class methods for Video Model
  module ClassMethods
    
    # Finders
    
    def all
      find(:all, :conditions => ["status = 'original' and created_at != ''"], :order => 'created_at  desc')
    end

    def recent_videos
      find(:all, :conditions => ["status = 'original'"], :limit => 10)
    end

    def recent_encodings
      find(:all, :conditions => ["status = 'sucess'"], :limit => 10)
    end

    def queued_encodings
      find(:all, :conditions => ["status = 'processing' or status = 'queued'"])
    end

    def next_job
      # TODO: change to outstanding_jobs and remove .first
      find(:all, :conditions => ["status = 'queued'"]).first
    end

    def outstanding_notifications
      find(:all, :conditions => ["'notification' != 'success' AND 'notification' != 'error' AND status = 'success' OR status = 'error'"]) #  sort 'last_notification_at' asc
    end

    def recently_completed_videos
     find(:all, :conditions => ["status = 'success'"])
    end
  end
  
  # Instance Method for Video Model
  module InstanceMethods
    
    def to_sym
      'videos'
    end

    # Classification
    # ==============

    def encoding?
      ['queued', 'processing', 'success', 'error'].include?(self.status)
    end
  
    # Only parent videos (no encodings)

    def parent_video
      self.class.find(self.parent)
    end

    def encodings
      self.class.find(:all, :conditions => ["parent = #{self.key}"])
    end

    def find_encoding_for_profile(p)
      self.class.query("['parent' = '#{self.key}'] intersection ['profile' = '#{p.key}']")
    end

    # Attr helpers
    # ============

    def obliterate!
      self.delete_from_s3
      self.encodings.each do |e|
        e.delete_from_s3
        e.destroy!
      end
      self.destroy!
    end

    # Location to store video file fetched from S3 for encoding
    def tmp_filepath
      Panda::Config[:tmp_video_dir] / self.filename
    end

    # Has the actual video file been uploaded for encoding?
    def empty?
      self.status == 'empty'
    end

    def upload_redirect_url
      Panda::Config[:upload_redirect_url].gsub(/\$id/,self.key.to_s)
    end

    def state_update_url
      Panda::Config[:state_update_url].gsub(/\$id/,self.key.to_s)
    end

    def duration_str
      s = (self.duration.to_i || 0) / 1000
      "#{sprintf("%02d", s/60)}:#{sprintf("%02d", s%60)}"
    end

    def resolution
      self.width ? "#{self.width}x#{self.height}" : nil
    end

    def video_bitrate_in_bits
      self.video_bitrate.to_i * 1024
    end

    def audio_bitrate_in_bits
      self.audio_bitrate.to_i * 1024
    end

    def screenshot
      self.filename + ".jpg"
    end

    def thumbnail
      self.filename + "_thumb.jpg"
    end

    def screenshot_url
      %(http://#{Panda::Config[:videos_domain]}/#{self.screenshot})
    end

    def thumbnail_url
      %(http://#{Panda::Config[:videos_domain]}/#{self.thumbnail})
    end

    # Encding attr helpers
    # ====================

    def url
      %(http://#{Panda::Config[:videos_domain]}/#{self.filename})
    end

    def embed_html
      return nil unless self.encoding?
      %(<embed src="http://#{Panda::Config[:videos_domain]}/flvplayer.swf" width="#{self.width}" height="#{self.height}" allowfullscreen="true" allowscriptaccess="always" flashvars="&displayheight=#{self.height}&file=#{self.url}&width=#{self.width}&height=#{self.height}&image=#{self.screenshot_url}" />)
    end

    def embed_js
      return nil unless self.encoding?
    	%(
    	<div id="flash_container_#{self.key[0..4]}"><a href="http://www.macromedia.com/go/getflashplayer">Get the latest Flash Player</a> to watch this video.</div>
    	<script type="text/javascript">
        var flashvars = {};

        flashvars.file = "#{self.url}";
        flashvars.image = "#{self.screenshot_url}";
        flashvars.width = "#{self.width}";
        flashvars.height = "#{self.height}";
        flashvars.fullscreen = "true";
        flashvars.controlbar = "over";
        var params = {wmode:"transparent",allowfullscreen:"true"};
        var attributes = {};
        attributes.align = "top";
        swfobject.embedSWF("http://#{Panda::Config[:videos_domain]}/player.swf", "flash_container_#{self.key[0..4]}", "#{self.width}", "#{self.height}", "9.0.115", "http://#{Panda::Config[:videos_domain]}/expressInstall.swf", flashvars, params, attributes);
    	</script>
    	)
  	end

    # S3
    # ==

    def upload_to_s3
      begin
        retryable(:tries => 5) do
          Merb.logger.info "Upload to S3"
          S3VideoObject.store(self.filename, File.open(self.tmp_filepath), :access => :public_read)
          sleep 3
        end
      rescue
        Merb.logger.error "Error uploading #{self.filename} to S3"
        raise
      else
        true
      end
    end

    def fetch_from_s3
      begin
        retryable(:tries => 5) do
          File.open(self.tmp_filepath, 'w') do |file|
            Merb.logger.info "Fetch from S3"
            S3VideoObject.stream(self.filename) {|chunk| file.write chunk}
          end
          sleep 3
        end
      rescue
        Merb.logger.error "Error fetching #{self.filename} from S3"
        raise
      else
        true
      end
    end

    def delete_from_s3
      begin
        retryable(:tries => 5) do
          Merb.logger.info "Deleting #{self.key} from S3"
          S3VideoObject.delete(self.filename)
          sleep 3
        end
      rescue
        Merb.logger.error "Error deleting #{self.filename} from S3"
        raise
      else
        true
      end
    end
    
    def capture_thumbnail_and_upload_to_s3
      screenshot_tmp_filepath = self.tmp_filepath + ".jpg"
      thumbnail_tmp_filepath = self.tmp_filepath + "_thumb.jpg"

      t = RVideo::Inspector.new(:file => self.tmp_filepath)
      puts self.tmp_filepath
      puts t.capture_frame('50%', screenshot_tmp_filepath)

      constrain_to_height = Panda::Config[:thumbnail_height_constrain].to_f
      width = (self.width.to_f/(self.height.to_f/constrain_to_height)).to_i
      height = constrain_to_height.to_i

      GDResize.new.resize(screenshot_tmp_filepath, thumbnail_tmp_filepath, [width,height])

      begin
        retryable(:tries => 5) do
          S3VideoObject.store(self.screenshot, File.open(screenshot_tmp_filepath), :access => :public_read)
          S3VideoObject.store(self.thumbnail, File.open(thumbnail_tmp_filepath), :access => :public_read)
        end
      rescue
        raise
      else
        true
      end
    end

    # Uploads
    # =======

    def process
      self.valid?
      self.read_metadata
      self.upload_to_s3
      self.add_to_queue
    end

    def valid?
      #raise NotValid unless self.empty?
      return true
    end

    def read_metadata
      Merb.logger.info "#{self.key}: Reading metadata of video file"
      inspector = RVideo::Inspector.new(:file => self.tmp_filepath)
      
      raise FormatNotRecognised unless inspector.valid? and inspector.video?
      
      self.duration = (inspector.duration rescue nil)
      self.container = (inspector.container rescue nil)
      self.width = (inspector.width rescue nil)
      self.height = (inspector.height rescue nil)

      self.video_codec = (inspector.video_codec rescue nil)
      self.video_bitrate = (inspector.bitrate rescue nil)
      self.fps = (inspector.fps rescue nil)

      self.audio_codec = (inspector.audio_codec rescue nil)
      self.audio_sample_rate = (inspector.audio_sample_rate rescue nil)

      raise FormatNotRecognised if self.duration == 0 # Don't allow videos with a duration of 0
      # raise FormatNotRecognised if self.width.nil? or self.height.nil? # Little final check we actually have some usable video
    end

    def create_encoding_for_profile(p)
      encoding = Video.new
      encoding.status = 'queued'
      encoding.save   # ID isn't created on new but on save, video.key == video.id so we save now and save later
      encoding.filename = "#{encoding.key}.#{p.container}"
      
      # Attrs from the parent video
      encoding.parent = self.key
      [:original_filename, :duration].each do |k|
        puts encoding.send("#{k}=", self.get(k))
      end

      # Attrs from the profile
      encoding.profile = p.key
      encoding.profile_title = p.title
      [:container, :width, :height, :video_codec, :video_bitrate, :fps, :audio_codec, :audio_bitrate, :audio_sample_rate, :player].each do |k|
        encoding.send("#{k}=", p.get(k))
      end
      encoding.save
      return encoding
    end

    # TODO: Breakout Profile adding into a different method
    def add_to_queue
      # Die if there's no profiles!
      if Profile.query.empty?
        Merb.logger.error "There are no encoding profiles!"
        return nil
      end
      # TODO: Allow manual selection of encoding profiles used in both form and api
      # For now we will just encode to all available profiles
      Profile.query.each do |p|
#        if Encoding.find_encoding_for_profile(p).empty?   # Bit confused here so'll just delete and see what happends - original - self.find_encoding_for_profile(p).empty?
        self.create_encoding_for_profile(p)
#        end
      end
      return true
    end
    

    # Exceptions

    class VideoError < StandardError; end
    class NotificationError < StandardError; end

    # 404
    class NotValid < VideoError; end

    # 500
    class NoFileSubmitted < VideoError; end
    class FormatNotRecognised < VideoError; end

    # API
    # ===

    def show_response
      # :filename, :original_filename, :parent, :status, :duration, :container, :width, :height, :video_codec, :video_bitrate, :fps, :audio_codec, :audio_bitrate, :audio_sample_rate, :profile, :profile_title, :player, :encoding_time, :encoded_at, :updated_at, :created_at

      r = {:video => {
          :id => self.key,
          :status => self.status
        }
      }

      # Common attributes for originals and encodings
      if self.status == 'original' or self.encoding?
        r[:video].merge!([:filename, :original_filename, :screenshot, :thumbnail, :width, :height, :duration].map_to_hash {|k| {k => self.send(k)} })
      end

      # If the video is a parent, also return the data for all its encodings
      if self.status == 'original'
        r[:video][:encodings] = self.encodings.map {|e| e.show_response}
      end

      # Reutrn extra attributes if the video is an encoding
      if self.encoding?
        r[:video].merge!([:parent, :profile, :profile_title, :encoded_at, :encoding_time].map_to_hash {|k| {k => self.send(k)} })
      end

      return r
    end

    def create_response
      {:video => {
          :id => self.key
        }
      }
    end

    # Notifications
    # =============

    def notification_wait_period
      (Panda::Config[:notification_frequency] * self.notification.to_i)
    end

    def time_to_send_notification?
      return true if self.last_notification_at.nil?
      Time.now > (self.last_notification_at + self.notification_wait_period)
    end

    def send_notification
      raise "You can only send the status of encodings" unless self.encoding?

      self.last_notification_at = Time.now
      begin
        puts '1'
        self.parent_video.send_status_update_to_client
        puts '2'
        self.notification = 'success'  
        puts '3'
        self.save
        puts '4'
        Merb.logger.info "Notification successfull"
      rescue
        # Increment num retries
        puts '5'
        if self.notification.to_i >= Panda::Config[:notification_retries]
          puts '6'
          self.notification = 'error'
        else
          puts '7'
          self.notification = self.notification.to_i + 1
        end
        self.save
        raise
        puts 'nah'
      end
    end

    def send_status_update_to_client
      Merb.logger.info "Sending notification to #{self.state_update_url}"
      puts self.state_update_url
      params = {"video" => self.show_response.to_yaml}
      puts params
      puts 'r'
      uri = URI.parse(self.state_update_url)
      puts uri.host
      puts uri
      puts self.state_update_url
      puts 'p'
      http = Net::HTTP.new(uri.host, uri.port)
      puts 'n'
      
      req = Net::HTTP::Post.new(uri.path)
      req.form_data = params
      response = http.request(req)
      puts response.code.to_i
      unless response.code.to_i == 200# and response.body.match /ok/
        ErrorSender.log_and_email("notification error", "Error sending notification for parent video #{self.key} to #{self.state_update_url} (POST)

  REQUEST PARAMS
  #{"="*60}\n#{params.to_yaml}\n#{"="*60}

  RESPONSE
  #{response.code} #{response.message} (#{response.body.length})
  #{"="*60}\n#{response.body}\n#{"="*60}")

        raise NotificationError
      end
      puts 'made'
    end

    # Encoding
    # ========

    def ffmpeg_resolution_and_padding
      # Calculate resolution and any padding
      in_w = self.parent_video.width.to_f
      in_h = self.parent_video.height.to_f
      out_w = self.width.to_f
      out_h = self.height.to_f

      begin
        aspect = in_w / in_h
      rescue
        Merb.logger.error "Couldn't do w/h to caculate aspect. Just using the output resolution now."
        return %(-s #{self.width}x#{self.height})
      end

      height = (out_w / aspect.to_f).to_i
      height -= 1 if height % 2 == 1

      opts_string = %(-s #{self.width}x#{height} )

      # Crop top and bottom is the video is too tall, but add top and bottom bars if it's too wide (aspect wise)
      if height > out_h
        crop = ((height.to_f - out_h) / 2.0).to_i
        crop -= 1 if crop % 2 == 1
        opts_string += %(-croptop #{crop} -cropbottom #{crop})
      elsif height < out_h
        pad = ((out_h - height.to_f) / 2.0).to_i
        pad -= 1 if pad % 2 == 1
        opts_string += %(-padtop #{pad} -padbottom #{pad})
      end

      return opts_string
    end

    def ffmpeg_resolution_and_padding_no_cropping
      # Calculate resolution and any padding
      in_w = self.parent_video.width.to_f
      in_h = self.parent_video.height.to_f
      out_w = self.width.to_f
      out_h = self.height.to_f

      begin
        aspect = in_w / in_h
        aspect_inv = in_h / in_w
      rescue
        Merb.logger.error "Couldn't do w/h to caculate aspect. Just using the output resolution now."
        return %(-s #{self.width}x#{self.height} )
      end

      height = (out_w / aspect.to_f).to_i
      height -= 1 if height % 2 == 1

      opts_string = %(-s #{self.width}x#{height} )

      # Keep the video's original width if the height
      if height > out_h
        width = (out_h / aspect_inv.to_f).to_i
        width -= 1 if width % 2 == 1

        opts_string = %(-s #{width}x#{self.height} )
        self.width = width
        self.save
      # Otherwise letterbox it
      elsif height < out_h
        pad = ((out_h - height.to_f) / 2.0).to_i
        pad -= 1 if pad % 2 == 1
        opts_string += %(-padtop #{pad} -padbottom #{pad})
      end

      return opts_string
    end

    def recipe_options(input_file, output_file)
      {
        :input_file => input_file,
        :output_file => output_file,
        :container => self.container, 
        :video_codec => self.video_codec,
        :video_bitrate_in_bits => self.video_bitrate_in_bits.to_s, 
        :fps => self.fps,
        :audio_codec => self.audio_codec.to_s, 
        :audio_bitrate => self.audio_bitrate.to_s, 
        :audio_bitrate_in_bits => self.audio_bitrate_in_bits.to_s, 
        :audio_sample_rate => self.audio_sample_rate.to_s, 
        :resolution => self.resolution,
        :resolution_and_padding => self.ffmpeg_resolution_and_padding_no_cropping
      }
    end

    def encode_flv_flash
      Merb.logger.info "Encoding with encode_flv_flash"
      puts '1'
      transcoder = RVideo::Transcoder.new
      puts '2'
      recipe = "ffmpeg -i $input_file$ -ar 22050 -ab $audio_bitrate$k -f flv -b $video_bitrate_in_bits$ -r 24 $resolution_and_padding$ -y $output_file$"
      puts '3'
      recipe += "\nflvtool2 -U $output_file$"
      puts '4'
      transcoder.execute(recipe, self.recipe_options(self.parent_video.tmp_filepath, self.tmp_filepath))
      puts '5'
    end

    def encode_mp4_aac_flash
      Merb.logger.info "Encoding with encode_mp4_aac_flash"
      transcoder = RVideo::Transcoder.new
      # Just the video without audio
      temp_video_output_file = "#{self.tmp_filepath}.temp.video.mp4"
      temp_audio_output_file = "#{self.tmp_filepath}.temp.audio.mp4"
      temp_audio_output_wav_file = "#{self.tmp_filepath}.temp.audio.wav"

      recipe = "ffmpeg -i $input_file$ -b $video_bitrate_in_bits$ -an -vcodec libx264 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.6 -qmin 10 -qmax 51 -qdiff 4 -coder 1 -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 -me hex -subq 5 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 $resolution_and_padding$ -r 24 -threads 4 -y $output_file$"
      recipe_audio_extraction = "ffmpeg -i $input_file$ -ar 48000 -ac 2 -y $output_file$"

      transcoder.execute(recipe, self.recipe_options(self.parent_video.tmp_filepath, temp_video_output_file))

      Merb.logger.info "Video encoding done"
      unless self.parent_video.audio_codec.blank?
        # We have to use nero to encode the audio as ffmpeg doens't support HE-AAC yet
        transcoder.execute(recipe_audio_extraction, recipe_options(self.parent_video.tmp_filepath, temp_audio_output_wav_file))
        Merb.logger.info "Audio extraction done"

        # Convert to HE-AAC
        %x(neroAacEnc -br #{self.audio_bitrate_in_bits} -he -if #{temp_audio_output_wav_file} -of #{temp_audio_output_file})
        Merb.logger.info "Audio encoding done"

        # Squash the audio and video together
        FileUtils.rm(self.tmp_filepath) if File.exists?(self.tmp_filepath) # rm, otherwise we end up with multiple video streams when we encode a few times!!
        %x(MP4Box -add #{temp_video_output_file}#video #{self.tmp_filepath})
        %x(MP4Box -add #{temp_audio_output_file}#audio #{self.tmp_filepath})

        # Interleave meta data
        %x(MP4Box -inter 500 #{self.tmp_filepath})
        Merb.logger.info "Squashing done"
      else
        Merb.logger.info "This video does't have an audio stream"
        FileUtils.mv(temp_video_output_file, self.tmp_filepath)
      end
    end

    def encode_unknown_format
      Merb.logger.info "Encoding with encode_unknown_format"
      transcoder = RVideo::Transcoder.new
      recipe = "ffmpeg -i $input_file$ -f $container$ -vcodec $video_codec$ -b $video_bitrate_in_bits$ -ar $audio_sample_rate$ -ab $audio_bitrate$k -acodec $audio_codec$ -r 24 $resolution_and_padding$ -y $output_file$"
      Merb.logger.info "Unknown encoding format given but trying to encode anyway."
      transcoder.execute(recipe, recipe_options(self.parent_video.tmp_filepath, self.tmp_filepath))
    end

    def encode
      raise "You can only encode encodings" unless self.encoding?
      self.status = "processing"
      self.save

      begun_encoding = Time.now

      begin
        encoding = self
        parent_obj = self.parent_video
        Merb.logger.info "(#{Time.now.to_s}) Encoding #{self.key}"

        parent_obj.fetch_from_s3
        if self.container == "flv" and self.player == "flash"
          puts 'encoding flv'
          self.encode_flv_flash
        elsif self.container == "mp4" and self.audio_codec == "aac" and self.player == "flash"
          self.encode_mp4_aac_flash
        else # Try straight ffmpeg encode
          self.encode_unknown_format
        end

        self.upload_to_s3
        #self.capture_thumbnail_and_upload_to_s3
        self.notification = 0
        self.status = "success"
        self.encoded_at = Time.now
        self.encoding_time = (Time.now - begun_encoding).to_i
        self.save
        Merb.logger.info "Removing tmp video files"
        FileUtils.rm self.tmp_filepath
        FileUtils.rm parent_obj.tmp_filepath

        Merb.logger.info "Encoding successful"
      rescue
        self.notification = 0
        self.status = "error"
        self.save
        FileUtils.rm parent_obj.tmp_filepath

        Merb.logger.error "Unable to transcode file #{self.key}: #{$!.class} - #{$!.message}"

        raise
      end
    end
  end
  
end