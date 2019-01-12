# frozen_string_literal: true

require 'spec_helper'
require Rails.root.join('db/migrate/20190112145833_create_invoice_items.rb')

describe CreateInvoiceItems do
  let(:migration) { CreateInvoiceItems.new }

  describe '#up' do
    before do
      migration.down
      InvoiceItem.reset_column_information
      Invoice.reset_column_information
    end

    it 'runs successfully' do
      expect { migration.up }.to_not raise_exception
    end

    it 'creates table invoice_items' do
      migration.up
      Invoice.reset_column_information
      InvoiceItem.reset_column_information

      expect(InvoiceItem.columns.map(&:name)).to include 'description', 'quantity', 'price'
    end

    it 'migrates data from invoice to invoice_item' do
      # Invoice initially has descrption and vat_percent fields
      invoice = create(:invoice)
      invoice.vat_percent = 30
      invoice.description =  [{ description: 'Sponsorship costs',
                                quantity: 1,
                                price: 1350 }]
      invoice.save!
      migration.up
      Invoice.reset_column_information
      InvoiceItem.reset_column_information

      expect(InvoiceItem.last.description).to eq 'Sponsorship costs'
      expect(InvoiceItem.last.quantity).to eq 1
      expect(InvoiceItem.last.price).to eq 1350
      expect(InvoiceItem.last.vat_percent).to eq 30
    end
  end

  describe '#down' do
    after :each do
      migration.up
    end

    it 'runs successfully' do
      expect { migration.down }.to_not raise_exception
    end

    it 'migrates data to invoice' do
      invoice = create(:invoice)
      invoice_item = create(:invoice_item, invoice: invoice,
                                           description: 'Ticket A',
                                           quantity: 2,
                                           price: 50)
      migration.down
      InvoiceItem.reset_column_information
      Invoice.reset_column_information
      invoice.reload
      expect(invoice.description).to eq [{ description: 'Ticket A',
                                           quantity: 2,
                                           price: 50 }]

      migration.up
      InvoiceItem.reset_column_information
      Invoice.reset_column_information
      invoice.reload

      expect(InvoiceItem.last.description).to eq 'Ticket A'
      migration.down
    end
  end
end
