class AddDiscountToTicketPurchase < ActiveRecord::Migration[5.0]
  def change
    add_column :ticket_purchases, :discount_percent, :float, default: 0
    add_column :ticket_purchases, :discount_value, :float, default: 0
  end
end
