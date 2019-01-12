class CreateInvoiceItems < ActiveRecord::Migration[5.0]
  class TempInvoice < ActiveRecord::Base
    self.table_name = 'invoices'
    serialize :description, Array
  end

  class TempInvoiceItem < ActiveRecord::Base
    self.table_name = 'invoice_items'
  end

  def up
    create_table :invoice_items do |t|
      t.string :description
      t.integer :quantity, default: 1
      t.float :price, default: 0
      t.float :vat, default: 0
      t.float :vat_percent, default: 0
      t.integer :position
      t.references :invoice, foreign_key: true
      t.references :conference, foreign_key: true

      t.timestamps
    end

    # Migrate information from invoice.description to invoice_items
    # Invoice description field is an array of hashes (with keys: description, quantity, price)
    TempInvoice.all.each do |invoice|
      invoice.description.each do |invoice_description|
        invoice_item = TempInvoiceItem.create!(description: invoice_description[:description],
                                               quantity: invoice_description[:quantity],
                                               price: invoice_description[:price],
                                               vat_percent: invoice.vat_percent,
                                               vat: invoice.vat,
                                               conference_id: invoice.conference_id,
                                               invoice_id: invoice.id)
      end

    end

    remove_column :invoices, :description, :text
    remove_column :invoices, :vat_percent, :float
  end

  def down
    add_column :invoices, :description, :text
    add_column :invoices, :vat_percent, :float, default: 0
    TempInvoice.reset_column_information
    TempInvoiceItem.all.group_by(&:invoice_id).each do |invoice_id, invoice_items|
      invoice = TempInvoice.find(invoice_id)
      invoice.description = []
      invoice_items.each do |invoice_item|
        invoice.description << { description: invoice_item.description,
                                 quantity: invoice_item.quantity,
                                 price: invoice_item.price }
      end

      invoice.save!
    end

    drop_table :invoice_items
  end
end
