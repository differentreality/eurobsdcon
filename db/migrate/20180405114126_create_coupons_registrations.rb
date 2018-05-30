class CreateCouponsRegistrations < ActiveRecord::Migration[5.0]
  def change
    create_table :coupons_registrations do |t|
      t.integer :coupon_id
      t.integer :registration_id
      t.datetime :applied_at, default: Time.current
    end
  end
end
