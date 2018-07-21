class CreateInvoices < ActiveRecord::Migration[5.0]
  def change
    create_table :invoices do |t|
      t.integer :no
      t.date :date
      t.references :recipient, polymorphic: true, index: true
      t.references :conference, foreign_key: true
      t.text :description
      t.text :recipient_details
      t.string :recipient_vat
      t.float :total_amount
      t.float :vat_percent
      t.float :vat
      t.float :payable
      t.string :currency
      t.boolean :paid
      t.integer :kind

      t.timestamps
    end
  end
end
