class AddDefaultValueInOverallDiscountToPayments < ActiveRecord::Migration[5.0]
  def change
    Payment.all.each do |payment|
      if payment.overall_discount.nil?
        payment.overall_discount = 0
        payment.save!
      end
    end

    change_column :payments, :overall_discount, :float, default: 0, null: false
  end
end
