# frozen_string_literal: true

class Payment < ApplicationRecord
  has_many :ticket_purchases
  belongs_to :user
  belongs_to :conference
  has_one :invoice

  attr_accessor :stripe_customer_email
  attr_accessor :stripe_customer_token
  attr_accessor :cardholder_name

  validates :status, presence: true
  validates :user_id, presence: true
  validates :conference_id, presence: true

  enum status: {
    unpaid: 0,
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
    # if ticket_purchases.any? is needed because otherwise .all? returns true
    ticket_purchases.all?{ |ticket_purchase| ticket_purchase.invoices.any? } if ticket_purchases.any?
  end

  def amount_to_pay
    Ticket.total_price(conference, user, paid: false, payment: nil).cents
  end

  def stripe_payment_details
    return nil unless authorization_code
    return Stripe::PaymentIntent.retrieve(authorization_code)
  end

  def create_intent(total_amount)
    Stripe::PaymentIntent.create({
      # Amount in cents and integer
      amount: (total_amount * 100).to_i,
      currency: conference.tickets.first.price_currency,
      receipt_email: user.email
    })
  end
end
