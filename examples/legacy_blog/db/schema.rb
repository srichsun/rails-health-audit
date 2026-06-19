# Intentionally missing indexes and foreign keys (active_record_doctor, Phase 2).
ActiveRecord::Schema.define(version: 2014_05_01_000000) do
  create_table "posts", force: :cascade do |t|
    t.string   "title"
    t.text     "body"
    t.integer  "user_id"        # no index, no foreign key
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tags", force: :cascade do |t|
    t.string  "name"
    t.integer "post_id"         # no index, no foreign key
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"            # no unique index
  end
end
