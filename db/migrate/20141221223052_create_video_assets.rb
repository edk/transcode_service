class CreateVideoAssets < ActiveRecord::Migration
  def change
    create_table :video_assets do |t|
      t.integer :original_id
      t.string  :type
      t.attachment :thumbnail
      t.attachment :asset

      t.timestamps
    end
  end
end
