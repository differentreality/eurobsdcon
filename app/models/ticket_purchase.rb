# frozen_string_literal: true

class TicketPurchase < ApplicationRecord
  belongs_to :ticket
  belongs_to :user
  belongs_to :conference
  belongs_to :payment

  validates :ticket_id, :user_id, :conference_id, :quantity, presence: true
  validate :one_registration_ticket_per_user
  validate :registration_ticket_already_purchased, on: :create
  validates :quantity, numericality: { greater_than: 0 }

  delegate :title, to: :ticket
  delegate :description, to: :ticket
  delegate :price, to: :ticket
  delegate :price_cents, to: :ticket
  delegate :price_currency, to: :ticket

  has_many :physical_tickets

  scope :paid, -> { where(paid: true) }
  scope :unpaid, -> { where(paid: false) }
  scope :by_conference, ->(conference) { where(conference_id: conference.id) }
  scope :by_user, ->(user) { where(user_id: user.id) }

  after_create :set_week

  def self.purchase(conference, user, purchases)
    errors = []
    errors << dependents_bought(conference, user, purchases)
    errors << 'You cannot buy more than one registration tickets.' if count_purchased_registration_tickets(conference, purchases) > 1
    errors << registered_to_buying(conference, user, purchases)

    unless errors.compact.any?
      ActiveRecord::Base.transaction do
        conference.tickets.each do |ticket|
          quantity = purchases[ticket.id.to_s].to_i
          # if the user bought the ticket and is still unpaid, just update the quantity
          purchase = if ticket.bought?(user) && ticket.unpaid?(user)
                       update_quantity(conference, quantity, ticket, user)
                     else
                       purchase_ticket(conference, quantity, ticket, user)
                     end
          if purchase && !purchase.save
            errors.push(purchase.errors.full_messages)
          end
        end
      end
    end
    errors.compact
  end

  ##
  # Does NOT include overall discounts
  def final_amount
    amount_paid - discount_value - discount_percent
  end

  def discount
    discount_value + discount_percent
  end

  def self.total_amount
    sum{ |tp| tp.quantity * tp.final_amount }
  end

  def final_amount_sum
    quantity * (amount_paid - discount)
  end

  def self.purchase_ticket(conference, quantity, ticket, user)
    if quantity > 0
      registration = user.registrations.for_conference(ticket.conference)
      purchase = new(ticket_id: ticket.id,
                     conference_id: conference.id,
                     user_id: user.id,
                     quantity: quantity,
                     amount_paid: ticket.price,
                     discount_percent: ticket.discount_percent(registration),
                     discount_value: ticket.discount_value(registration))
      purchase.pay(nil) if ticket.price_cents.zero?
    end
    purchase
  end

  def self.update_quantity(conference, quantity, ticket, user)
    purchase = TicketPurchase.where(ticket_id:     ticket.id,
                                    conference_id: conference.id,
                                    user_id:       user.id,
                                    paid:          false).first

    purchase.quantity = quantity if quantity > 0
    purchase
  end

  # Total amount
  def self.total
    sum('amount_paid * quantity')
  end

  def pay(payment)
    update_attributes(paid: true, payment: payment)
    PhysicalTicket.transaction do
      quantity.times { physical_tickets.create }
    end
    Mailbot.ticket_confirmation_mail(self).deliver_later
  end

  def one_registration_ticket_per_user
    if ticket.try(:registration_ticket?) && quantity != 1
      errors.add(:quantity, 'cannot be greater than one for registration tickets.')
    end
  end

  def registration_ticket_already_purchased
    if ticket.try(:registration_ticket?) && user.tickets.for_registration(conference).present?
      errors.add(:quantity, 'cannot be greater than one for registration tickets.')
    end
  end
end

private

def set_week
  self.week = created_at.strftime('%W')
  save!
end

##
# If user is buying a ticket for a specific event,
# check if user is already registered to that event
def registered_to_buying(conference, user, purchases)
  errors = []
  purchases = purchases.map{|k, v| [k, v] if v.to_i > 0 }.compact.to_h
  buying_tickets = purchases.keys.map{ |ticket_id| Ticket.find(ticket_id) }

  buying_tickets.each do |ticket|
    ticket_events_with_registration = ticket.event if ticket.event.require_registration

    if ticket_events_with_registration.any?
      if !ticket_events_with_registration.any?{ |event| user.registered_to_event?(event) }
        errors << "To buy ticket #{ticket.title} you first need to register #{ticket_events_with_registration.length > 1 ? 'to at least one of its events' : 'to'} (#{ticket_events_with_registration.pluck(:title).join(', ')})"
      end
    end
  end
  result = errors.any? ? errors.join('. ') : nil
  return result
end

##
# If a ticket depends on another ticket, user needs to buy both
def dependents_bought(conference, user, purchases)
  errors = []
  purchases = purchases.map{|k, v| [k, v] if v.to_i > 0 }.compact.to_h
  user_tickets = user.ticket_purchases.where(conference: conference).pluck(:ticket_id) + purchases.keys.map(&:to_i)
  buying_tickets = purchases.keys.map{ |ticket_id| Ticket.find(ticket_id) }

  buying_tickets.each do |ticket|
    if ticket.dependent && !user_tickets.include?(ticket.dependent_id)
      errors << "Ticket #{ticket.title} requires ticket #{ticket.dependent.title} to be bought as well"
    end
  end
  result = errors.any? ? errors.join('. ') : nil
  return result
end

def count_purchased_registration_tickets(conference, purchases)
  conference.tickets.for_registration.inject(0) do |sum, registration_ticket|
    sum + purchases[registration_ticket.id.to_s].to_i
  end
end
