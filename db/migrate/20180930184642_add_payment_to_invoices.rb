class AddPaymentToInvoices < ActiveRecord::Migration[5.0]
  def change
    add_reference :invoices, :payment, foreign_key: true
  end
end
