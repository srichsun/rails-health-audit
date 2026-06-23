# Intentionally unhealthy schema — used to demonstrate the runtime (Phase 2) audit.
# Every "missing" thing below is on purpose so active_record_doctor / lol_dba light up:
#   - no foreign keys           -> missing_foreign_keys
#   - foreign-key cols unindexed -> unindexed_foreign_keys / lol_dba
#   - presence-validated col nullable -> missing_non_null_constraint
#   - uniqueness-validated col without a unique index -> missing_unique_indexes
class CreateSchema < ActiveRecord::Migration[8.0]
  def change
    create_table :owners do |t|
      t.string :name
      t.string :email
      t.timestamps
    end

    create_table :products do |t|
      t.string  :name            # presence-validated in the model, but left nullable
      t.string  :sku             # uniqueness-validated in the model, but no unique index
      t.integer :owner_id        # belongs_to :owner, but no FK and no index
      t.integer :price_cents
      t.timestamps
    end

    create_table :tags do |t|
      t.string  :name
      t.integer :product_id      # belongs_to :product, but no FK and no index
      t.timestamps
    end
  end
end
