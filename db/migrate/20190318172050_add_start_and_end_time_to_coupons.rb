class AddStartAndEndTimeToCoupons < ActiveRecord::Migration[5.0]
  def change
    add_column :coupons, :start_time, :datetime
    add_column :coupons, :end_time, :datetime
  end
end
