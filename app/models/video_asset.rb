class VideoAsset < ActiveRecord::Base
  # TODO - make private, use hash?
  # tests
  # move to S3
  # use dotenv
  #

  has_attached_file :asset, s3_permissions: 'private', :styles => {
    :mp4 => { :format => 'mp4' },
    :ogg => { :format => 'ogg' },
    :thumb =>  { :geometry => "300x200", :format => 'jpg' },
  }, :processors => [:transcoder]

  validates_attachment_content_type :asset, :content_type => ["vidoe/webm", "video/mp4", "video/ogg", "video/mp4", "video/quicktime"]
end
