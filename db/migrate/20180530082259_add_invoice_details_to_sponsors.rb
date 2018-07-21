class AddInvoiceDetailsToSponsors < ActiveRecord::Migration[5.0]
  def change
    add_column :sponsors, :invoice_details, :text
    add_column :sponsors, :invoice_vat, :string
  end
end
