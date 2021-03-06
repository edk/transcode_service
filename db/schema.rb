# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160109204532) do

  create_table "api_tokens", force: true do |t|
    t.string   "user"
    t.string   "token"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "api_tokens", ["token"], name: "index_api_tokens_on_token", unique: true

  create_table "transcode_events", force: true do |t|
    t.integer  "transcode_job_id"
    t.string   "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "transcode_jobs", force: true do |t|
    t.string   "aasm_state"
    t.integer  "video_asset_id"
    t.string   "video_asset_secret"
    t.string   "callback_url"
    t.string   "name"
    t.text     "params"
    t.text     "log"
    t.string   "asset_file_name"
    t.string   "asset_content_type"
    t.integer  "asset_file_size"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.string   "type"
    t.string   "job_id"
  end

  create_table "video_assets", force: true do |t|
    t.integer  "original_id"
    t.string   "type"
    t.string   "thumbnail_file_name"
    t.string   "thumbnail_content_type"
    t.integer  "thumbnail_file_size"
    t.datetime "thumbnail_updated_at"
    t.string   "asset_file_name"
    t.string   "asset_content_type"
    t.integer  "asset_file_size"
    t.datetime "asset_updated_at"
    t.text     "asset_meta"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
