class AddInvoiceDetailsToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :invoice_details, :text
    add_column :users, :invoice_vat, :string, default: ''
  end
end
