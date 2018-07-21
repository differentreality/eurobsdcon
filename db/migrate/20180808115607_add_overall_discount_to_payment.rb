class AddOverallDiscountToPayment < ActiveRecord::Migration[5.0]
  def change
    add_column :payments, :overall_discount, :float
  end
end
