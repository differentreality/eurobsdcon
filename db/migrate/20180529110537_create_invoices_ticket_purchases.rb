class CreateInvoicesTicketPurchases < ActiveRecord::Migration[5.0]
  def change
    create_table :invoices_ticket_purchases do |t|
      t.references :invoice
      t.references :ticket_purchase
      t.integer :total_quantity
      t.decimal :invoice_payable
      t.timestamps
    end
  end
end
