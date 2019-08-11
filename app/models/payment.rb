# frozen_string_literal: true

class Payment < ApplicationRecord
  has_many :ticket_purchases
  belongs_to :user
  belongs_to :conference
  has_one :invoice

  attr_accessor :stripe_customer_email
  attr_accessor :stripe_customer_token

  validates :status, presence: true
  validates :user_id, presence: true
  validates :conference_id, presence: true

  enum status: {
    unpaid:  0,
    success: 1,
    failure: 2
  }

  def self.successful
    where(status: 1)
  end

  def not_invoiced?
    ticket_purchases.any?{ |ticket_purchase| !ticket_purchase.invoices.any? }
  end

  def invoiced?
    ticket_purchases.all?{ |ticket_purchase| ticket_purchase.invoices.any? }
  end

  def amount_to_pay
    Ticket.total_price(conference, user, paid: false, payment: nil).cents
  end

  def purchase
    gateway_response = Stripe::Charge.create source:        stripe_customer_token,
                                             receipt_email: stripe_customer_email,
                                             description:   "ticket purchases(#{user.username})",
                                             amount:        amount_to_pay,
                                             currency:      conference.tickets.first.price_currency

    self.amount = gateway_response[:amount]
    self.last4 = gateway_response[:source][:last4]
    self.authorization_code = gateway_response[:id]
    self.status = 'success'
    true

  rescue Stripe::StripeError => error
    errors.add(:base, error.message)
    self.status = 'failure'
    false
  end
end
