class AddExchangeRateToInvoices < ActiveRecord::Migration[5.0]
  def change
    add_column :invoices, :exchange_rate, :float, default: 0
  end
end
