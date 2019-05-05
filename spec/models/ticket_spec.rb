# frozen_string_literal: true

require 'spec_helper'

describe Ticket do
  let(:conference) { create(:conference) }
  let(:ticket) { create(:ticket, price: 50, price_currency: 'USD', conference: conference) }
  let(:user) { create(:user) }

  describe 'validation' do

    it 'has a valid factory' do
      expect(build(:ticket)).to be_valid
    end

    it 'is not valid without a title' do
      should validate_presence_of(:title)
    end

    it 'is not valid without a price_cents' do
      should validate_presence_of(:price_cents)
    end

    it 'is not valid without a price_currency' do
      should validate_presence_of(:price_currency)
    end

    it 'is not valid with a price_cents smaller than zero' do
      should_not allow_value(-1).for(:price_cents)
    end

    it 'is valid with a price_cents equals zero' do
      should allow_value(0).for(:price_cents)
    end

    it 'is valid with a price_cents greater than zero' do
      should allow_value(1).for(:price_cents)
    end

    it 'is not valid if tickets of conference do not have same currency' do
      conflicting_currency_ticket = build(:ticket,
                                          conference:     ticket.conference,
                                          price_currency: 'INR')
      expected_error_message = 'Price currency is different from the existing tickets of this conference.'

      expect(conflicting_currency_ticket).not_to be_valid
      expect(conflicting_currency_ticket.errors.full_messages).to eq([expected_error_message])
    end
  end

  describe 'association' do
    it { is_expected.to belong_to(:conference) }
    it { is_expected.to belong_to(:event) }
    it { is_expected.to have_many(:ticket_purchases).dependent(:destroy) }
    it { is_expected.to have_many(:buyers).through(:ticket_purchases).source(:user) }
  end

  describe '#bought?' do
    it 'returns true if the user has bought this ticket' do
      create(:ticket_purchase,
             user:   user,
             ticket: ticket)
      expect(ticket.bought?(user)).to eq(true)
    end

    it 'returns false if the user has not bought this ticket' do
      expect(ticket.bought?(user)).to eq(false)
    end
  end

  describe '#discount_value' do
    it 'returns correct amount' do
      registration = create(:registration, user: user, conference: conference)
      coupon_ticket_value = create(:coupon_value, conference: conference, ticket: ticket, discount_amount: 10)
      coupon_ticket_percent = create(:coupon_percent, conference: conference, ticket: ticket, discount_amount: 10)
      coupon_value = create(:coupon_value, conference: conference, discount_amount: 10)
      coupon_percent = create(:coupon_percent, conference: conference, discount_amount: 10)
      registration.coupon_ids = [coupon_ticket_value.id, coupon_ticket_percent.id, coupon_value.id, coupon_percent.id]
      expect(ticket.discount_value(registration)).to eq 10
      expect(ticket.discount_percent(registration)).to eq 5
      expect(ticket.discount_overall_value(registration)).to eq 10
      expect(ticket.discount_overall_percent(registration)).to eq 5
    end
  end

  describe '#tickets_turnover_total' do
    let!(:purchase1) { create :ticket_purchase, ticket: ticket, amount_paid: 5_000, quantity: 1, paid: true, user: user }
    let!(:purchase2) { create :ticket_purchase, ticket: ticket, amount_paid: 5_000, quantity: 2, paid: true, user: user }
    let!(:purchase3) { create :ticket_purchase, ticket: ticket, amount_paid: 5_000, quantity: 10, paid: false, user: user }
    subject { ticket.tickets_turnover_total ticket.id }

    it 'returns turnover as Money with ticket\'s currency' do
      is_expected.to eq Money.new(5_000 * 3, ticket.price_currency)
    end
  end

  describe '#active?' do
    let(:ticket_without_dates) { create(:ticket, start_date: nil, end_date: nil)}
    let(:ticket_with_dates) { create(:ticket, start_date: Date.current - 1, end_date: Date.current + 2)}
    let(:ticket_later) { create(:ticket, start_date: Date.current + 1, end_date: Date.current + 2)}
    let(:ticket_previously) { create(:ticket, start_date: Date.current - 2, end_date: Date.current - 1)}

    context 'returns false' do
      it 'when current time before start_date' do
        expect(ticket_later.active?).to eq false
      end

      it 'when current time after end_date' do
        expect(ticket_previously.active?).to eq false
      end

      it 'when current time before start_date with nil end_date' do
        ticket_later.end_date = nil
        ticket_later.save!
        ticket_later.reload

        expect(ticket_later.active?).to eq false
      end

      it 'when current time after end_date with nil start_date' do
        ticket_previously.start_date = nil
        ticket_previously.save!
        ticket_previously.reload

        expect(ticket_previously.active?).to eq false
      end
    end

    context 'returns true' do
      it 'when there is no start_date or end_date' do
        expect(ticket_without_dates.active?).to eq true
      end

      it 'when current time is within range' do
        expect(ticket_with_dates.active?).to eq true
      end

      it 'when current time after start_date with nil end_date' do
        ticket_with_dates.end_date = nil
        ticket_with_dates.save!
        ticket_with_dates.reload

        expect(ticket_with_dates.active?).to eq true
      end

      it 'when current time before end_date with nil start_date' do
        ticket_with_dates.start_date = nil
        ticket_with_dates.save!
        ticket_with_dates.reload

        expect(ticket_with_dates.active?).to eq true
      end
    end
  end

  describe '#unpaid?' do
    let!(:ticket_purchase) { create(:ticket_purchase, user: user, ticket: ticket, payment_id: nil) }

    context 'user has not paid' do

      it 'returns true' do
        expect(ticket.unpaid?(user)).to eq(true)
      end
    end

    context 'user has paid' do
      before { ticket_purchase.update_attributes(paid: true, payment: create(:payment, user: user, conference: conference)) }

      it 'returns false' do
        expect(ticket.unpaid?(user)).to eq(false)
      end
    end
  end

  describe '#tickets_paid' do
    before do
      create(:ticket_purchase, user: user, ticket: ticket)
      create(:ticket_purchase, user: user, ticket: ticket, paid: true)
    end

    it 'returns correct number of paid/total tickets' do
      expect(ticket.tickets_paid(user)).to eq('10/20')
    end
  end

  describe '#quantity_bought_by' do
    context 'user has not paid' do
      it 'returns the correct value if the user has bought this ticket' do
        create(:ticket_purchase,
               user:     user,
               ticket:   ticket,
               quantity: 20)
        expect(ticket.quantity_bought_by(user, paid: false)).to eq(20)
      end

      it 'returns zero if the user has not bought this ticket' do
        expect(ticket.quantity_bought_by(user, paid: false)).to eq(0)
      end
    end

    context 'user has paid' do
      let!(:ticket_purchase) { create(:ticket_purchase, user: user, ticket: ticket, quantity: 20) }
      before { ticket_purchase.update_attributes(paid: true) }

      it 'returns the correct value if the user has bought and paid for this ticket' do
        expect(ticket.quantity_bought_by(user, paid: true)).to eq(20)
      end
    end
  end

  describe '#total_price' do
    context 'user has not paid' do
      it 'returns the correct value if the user has bought this ticket' do
        create(:ticket_purchase,
               user:     user,
               ticket:   ticket,
               quantity: 20)
        expect(ticket.total_price(user, paid: false)).to eq(Money.new(100000, 'USD'))
      end

      it 'returns zero if the user has not bought this ticket' do
        expect(ticket.total_price(user, paid: false)).to eq(Money.new(0, 'USD'))
      end
    end

    context 'user has paid' do
      let!(:ticket_purchase) { create(:ticket_purchase, user: user, ticket: ticket, quantity: 20) }
      before { ticket_purchase.update_attributes(paid: true) }

      it 'returns the correct value if the user has bought this ticket' do
        expect(ticket.total_price(user, paid: true)).to eq(Money.new(100000, 'USD'))
      end
    end
  end

  describe '#ticket_discount' do
    it 'returns total amount of discount for ticket' do
      ticket = create(:ticket, conference: conference, price: 100)
      create(:coupon_value, discount_amount: 10)
      create(:coupon_percent, discount_amount: 10)
      create(:ticket_purchase, ticket: ticket, user: user, discount_value: 10, discount_percent: 10)

      expect(ticket.ticket_discount(user)).to eq 20
    end
  end

  describe 'self.total_price' do
    let(:diversity_supporter_ticket) { create(:ticket, conference: conference, price: 500) }

    describe 'user has bought' do
      context 'no tickets' do
        it 'returns zero' do
          expect(Ticket.total_price(conference, user, paid: false)).to eq(Money.new(0, 'USD'))
        end
      end

      context 'one type of ticket' do
        before do
          create(:ticket_purchase, ticket: ticket, user: user, quantity: 20)
        end

        it 'returns the correct total price' do
          expect(Ticket.total_price(conference, user, paid: false)).to eq(Money.new(100000, 'USD'))
        end
      end

      context 'multiple types of tickets' do
        before do
          create(:ticket_purchase, ticket: ticket, user: user, quantity: 20)
          create(:ticket_purchase, ticket: diversity_supporter_ticket, user: user, quantity: 2)
        end

        it 'returns the correct total price' do
          total_price = Money.new(200000, 'USD')
          expect(Ticket.total_price(conference, user, paid: false)).to eq(total_price)
        end
      end
    end
  end

  describe 'currency updation' do
    context 'when more than one ticket exist for a conference' do
      it 'should not allow currency update' do
        ticket.update(price_currency: 'INR')
        expected_error_message = 'Price currency is different from the existing tickets of this conference.'
        expect(ticket.errors.full_messages).to eq([expected_error_message])
      end
    end

    context 'when a single ticket exists for a conference' do
      before do
        ticket.destroy
      end

      it 'should allow currency update' do
        free_ticket = Ticket.first
        expect { free_ticket.update_attributes(price_currency: 'INR') }.to change { free_ticket.reload.price_currency }.from('USD').to('INR')
      end
    end
  end
end
