class RemoveVatPercentInInvoices < ActiveRecord::Migration[5.0]
  def change
    remove_column :invoices, :vat_percent, :float
  end
end
