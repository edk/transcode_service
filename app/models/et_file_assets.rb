
# Elastic Transcoder File Assets
class ETFileAssets

  def initialize options
    @source = options[:source]
    @source_bucket = options[:source_bucket]
    @transcode_in = options[:transcode_in]
    @transcode_out = options[:transcode_out]
    @local_job = options[:local_job]
    @transcode_buckets = options[:transcode_buckets]
  end

  def copy_from_source_to_ets_input force_copy = false
    #### copy from video asset to transcoder in bucket

    # If transcode out in bucket already has the same object, skip the copy
    key = @local_job.video_asset.asset.path
    found = true
    begin
      transcode_resp = @transcode_in.head_object( bucket: @transcode_buckets[:in], key: key )
    rescue
      found = false
    end

    if !found || force_copy
      resp           = @source.get_object( bucket: @source_bucket, key: key )
      transcode_resp = @transcode_in.put_object( bucket: @transcode_buckets[:in], key: key, body: resp.body )
      @local_job.log_string "Copied #{key} from #{@source_bucket} to #{@transcode_buckets[:in]}"
      transcode_resp
    else
      true
    end
  end

  def move_from_ets_output_to_source
    @local_job.log_string "Completing job ID: #{ets.job_response.job.id}"

    input_key  = @local_job.video_asset.asset.path
    out_key = input_key.split('.')[0..-2].join('.')

    # look for all the objects
    all_objs_resp = @transcode_out.list_objects( bucket: @transcode_buckets[:out], prefix: out_key )
    all_objs      = all_objs_resp.contents.map {|o| o.key }

    #### on success copy assets back to the right original bucket, deleting in and out bucket objects
    styles = @local_job.video_asset.asset.styles.keys
    thumb_keys, keys = styles.map {|style| @local_job.video_asset.asset.path(style) }.partition { |k| k =~ /\.(png|jpg)$/ }
    
    # copy out of and delete from transcode out bucket
    keys.each do |target_key|
      # target key needs to look something like this:            video_assets/assets/000/000/014/mp4/my_video.mp4
      # key is missing the /:style/ in the transcode out bucket: video_assets/assets/000/000/014/my_video.mp4
      key = all_objs.detect { |o| target_key.split('/').last == o.split('/').last }
      s3_resp_source = @transcode_out.get_object( bucket: @transcode_buckets[:out], key: key )
      s3_resp_target = @source.put_object( bucket: @source_bucket, key: target_key, body: s3_resp_source.body )
      @local_job.log_string "Copied from #{@transcode_buckets[:out]}/#{key} to #{@source_bucket}/#{target_key}"
      delete_resp = @transcode_out.delete_object( bucket: @transcode_buckets[:out], key: key )
      @local_job.log_string "Deleted #{key} from #{@transcode_buckets[:out]} #{delete_resp.inspect}"
    end
    
    # handle thumbnails.  AWS doesn't allow a single thumbnail
    thumb_keys = all_objs.select {|o| o =~ /(png|jpg)$/ }
    
    # copy the first thumb_key, delete them all when done.
    thumb_key = thumb_keys.first
    source_thumb_key = @local_job.video_asset.asset.path(:thumb)
    s3_resp_source = @transcode_out.get_object( bucket: @transcode_buckets[:out], key: thumb_key )
    s3_resp_target = @source.put_object( bucket: @source_bucket, key: source_thumb_key, body: s3_resp_source.body )
    @local_job.log_string "Copied from #{@transcode_buckets[:out]}/#{thumb_key} to #{@source_bucket}/#{source_thumb_key}"
    
    delete_resp = @transcode_out.delete_objects( bucket: @transcode_buckets[:out], delete: { objects: thumb_keys.map {|k| {key: k} } } )
    @local_job.log_string "Deleted #{thumb_keys.count} thumbnail keys from #{@transcode_buckets[:out]} #{delete_resp.inspect}"
    
    key = @local_job.video_asset.asset.path(:original)
    delete_resp = @transcode_out.delete_object( bucket: @transcode_buckets[:in], key: key )
    @local_job.log_string "Deleted #{key} from #{@transcode_buckets[:in]} #{delete_resp.inspect}"    
  end
end


