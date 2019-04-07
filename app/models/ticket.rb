# frozen_string_literal: true

class Ticket < ApplicationRecord
  belongs_to :conference
  has_many :coupons
  # Ticket X depends on ticket Y, so you can't buy X without buying Y as well
  belongs_to :dependent, class_name: 'Ticket'
  has_many :ticket_purchases, dependent: :destroy
  belongs_to :event
  has_many :buyers, -> { distinct }, through: :ticket_purchases, source: :user

  has_paper_trail meta:   { conference_id: :conference_id },
                  ignore: %i[updated_at]

  monetize :price_cents, with_model_currency: :price_currency

  scope :for_registration, -> { where(registration_ticket: true) }

  # This validation is for the sake of simplicity.
  # If we would allow different currencies per conference we also have to handle convertions between currencies!
  validate :tickets_of_conference_have_same_currency

  validates :price_cents, :price_currency, :title, presence: true

  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }

  def bought?(user)
    buyers.include?(user)
  end

  ##
  # Sums the discount of ticket
  # based on the unpaid ticket purchases of the user
  def ticket_discount(user, paid: false)
    ticket_purchases.by_user(user).where(paid: paid).sum{ |tp| (tp.discount_value || 0) + (tp.discount_percent || 0) }
  end

  def discount(registration)
    discount_value(registration) + discount_percent(registration)
  end
  ##
  # Calculate ticket discount for specific user registration
  # Returns price minus all discounts (percent and value)
  # ==== Returns
  # * +Money+ -> ticket price minus discounts

  # calc_ticket_discount
  def discount_for_ticket(registration)
    return Money.new(0, self.price_currency) unless registration
    discount_percent = registration.coupons.joins(:ticket).where(ticket: self).select(&:percent?).sum(&:discount_amount)
    discount_value = registration.coupons.joins(:ticket).where(ticket: self).select(&:value?).sum(&:discount_amount)
    total_discount = (price*discount_percent/100).to_f + discount_value
    return Money.new(total_discount * 100, self.price_currency)
  end

  def discount_value(registration)
    return Money.new(0, self.price_currency) unless registration
    discount_value = registration.coupons.joins(:ticket).where(ticket: self).select(&:value?).sum(&:discount_amount)
    # No need to multiply by 100 here, because amount_paid is already in price cents
    # so amount_paid is 0.1 instead of 100, and we want the discount to be at the same scale
    return discount_value#, self.price_currency)
  end

  def discount_percent(registration)
    return Money.new(0, self.price_currency) unless registration
    discount = registration.coupons.joins(:ticket).where(ticket: self).select(&:percent?).sum(&:discount_amount)
    discount_percent = (price*discount/100).to_f
    return discount_percent# * 100, self.price_currency)
  end

  def discount_overall_value(registration)
    return 0 unless registration
    coupons = registration.coupons - registration.coupons.joins(:ticket)
    discount_overall_value = coupons.select(&:value?).sum(&:discount_amount)
    # No need to multiply by 100 here, because amount_paid is already in price cents
    # so amount_paid is 0.1 instead of 100, and we want the discount to be at the same scale
    return discount_overall_value#, registration.conference.tickets.first.price_currency)
  end

  def discount_overall_percent(registration)
    return 0 unless registration
    coupons = registration.coupons - registration.coupons.joins(:ticket)
    discount = coupons.select(&:percent?).sum(&:discount_amount)
    discount_overall_percent = (price * discount/100).to_f
    return discount_overall_percent #* 100, registration.conference.tickets.first.price_currency)
  end

  def active?
    return true unless start_date || end_date
    if start_date && end_date
      (start_date..end_date).cover? Time.current
    elsif start_date
      Time.current >= start_date
    elsif end_date
      Time.current <= end_date
    end
  end

  def tickets_paid(user)
    paid_tickets    = quantity_bought_by(user, paid: true)
    unpaid_tickets  = quantity_bought_by(user, paid: false)
    "#{paid_tickets}/#{paid_tickets + unpaid_tickets}"
  end

  def quantity_bought_by(user, paid: false, payment: nil)
    ticket_purchases.by_user(user).where(paid: paid).where(payment: payment).sum(:quantity)
  end

  def paid?(user)
    ticket_purchases.paid.by_user(user).present?
  end

  def unpaid?(user, payment: nil)
    ticket_purchases.where(payment: payment).unpaid.by_user(user).present?
  end

  def total_price(user, paid: false, payment: nil)
    user_registration = user.registrations.for_conference conference

    quantity_bought_by(user, paid: paid, payment: payment) * price - quantity_bought_by(user, paid: paid, payment: payment) * Money.new(discount_for_ticket(user_registration), price_currency)
  end

  def self.total_price(conference, user, paid: false, payment: nil)
    tickets = Ticket.where(conference_id: conference.id)
    result = nil
    begin
      tickets.each do |ticket|
        price = ticket.total_price(user, paid: paid, payment: payment)
        if result
          result += price unless price.zero?
        else
          result = price
        end
      end
    rescue Money::Bank::UnknownRate
      result = Money.new(-1, 'USD')
    end
    result ? result : Money.new(0, 'USD')
  end

  def self.total_price_user(conference, user, paid: false)
    tickets = TicketPurchase.where(conference: conference, user: user, paid: paid)
    tickets.map{ |tp| tp.payment }.compact.uniq.pluck(:amount).sum / 100
    # tickets.inject(0){ |sum, ticket| sum + (ticket.final_amount * ticket.quantity) }
  end

  def tickets_turnover_total(id)
    ticket = Ticket.find(id)
    return Money.new(0, 'USD') unless ticket
    sum = ticket.ticket_purchases.paid.total_amount
    Money.new(sum, ticket.price_currency)
  end

  def tickets_sold
    ticket_purchases.paid.sum(:quantity)
  end

  private

  def tickets_of_conference_have_same_currency
    tickets = Ticket.where(conference_id: conference_id)
    return if tickets.count.zero? || (tickets.count == 1 && self == tickets.first)

    unless tickets.all?{|t| t.price_currency == price_currency }
      errors.add(:price_currency, 'is different from the existing tickets of this conference.')
    end
  end
end
