# frozen_string_literal: true

class Invoice < ApplicationRecord
  belongs_to :recipient, polymorphic: true
  belongs_to :conference
  belongs_to :payment
  # serialize :description, Array
  has_many :invoice_items, dependent: :destroy

  accepts_nested_attributes_for :invoice_items, allow_destroy: true

  has_and_belongs_to_many :ticket_purchases

  has_paper_trail ignore: [:updated_at], meta: { conference_id: :conference_id }

  validates :no, :date, :payable, presence: true
  validates :no, numericality: { greater_than: 0 }, uniqueness: { scope: :conference_id }

  enum kind: {
    sponsorship: 0,
    ticket_purchase: 1
  }

  def number
    "#{date.strftime('%Y')}-#{no.to_s.rjust(3, '0')}"
  end
end
