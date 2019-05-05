class Invoice < ApplicationRecord
  # has_paper_trail

  belongs_to :recipient, polymorphic: true
  belongs_to :conference
  belongs_to :payment
  serialize :description, Array

  has_and_belongs_to_many :ticket_purchases

  validates :no, :date, :payable, presence: true
  validates :no, numericality: { greater_than: 0 }, uniqueness: { scope: :conference_id }

  enum kind: {
    sponsorship: 0,
    ticket_purchase: 1
  }

  def number
    "#{date.strftime('%Y')}-#{no.to_s.rjust(3, '0')}"
  end

  ##
  # Run script for EUR-NOK exchange
  # Script returns the latest exchange rates
  # Get the latest exchange rate
  # ==== Returns
  # * +Float+ -> exchange rate for EUR->NOK
  def self.exchange_rate
    nok_rate_results = `./euro-nok-conversion.perl`
    nok_rate_results.lines.last&.split(',').last.to_f
  end
end
