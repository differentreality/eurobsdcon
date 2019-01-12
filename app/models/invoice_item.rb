# frozen_string_literal: true

class InvoiceItem < ApplicationRecord
  belongs_to :conference
  belongs_to :invoice

  acts_as_list scope: :conference

  has_paper_trail ignore: [:updated_at], meta: { conference_id: :conference_id }

  validates :description, :quantity, :price, :vat, :vat_percent, :invoice_id, presence: true
end
