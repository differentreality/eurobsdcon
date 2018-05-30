class CreateCoupons < ActiveRecord::Migration[5.0]
  def change
    create_table :coupons do |t|
      t.string :name
      t.text :description
      t.integer :discount_type, default: 0
      t.float :discount_amount, default: 0
      t.references :conference, foreign_key: true
      t.references :ticket, foreign_key: true

      t.timestamps
    end
  end
end
