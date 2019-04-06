class AddMaxTimesToCoupons < ActiveRecord::Migration[5.0]
  def change
    add_column :coupons, :max_times, :integer, default: 0
  end
end
