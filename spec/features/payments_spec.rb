# frozen_string_literal: true

require 'spec_helper'

feature Payment do
  let!(:conference) { create(:conference_with_tickets) }
  let!(:admin) { create(:user) }
  let!(:user) { create(:user) }
  let!(:ticket) { create(:ticket, conference: conference) }
  let!(:second_ticket) { create(:ticket, conference: conference) }

  after(:each) do
    sign_out
  end

  context 'user buys ticket with online payment' do
    before(:each) do
      sign_in user
    end

    scenario 'online successfully', feature: true, js: true do
      visit conference_tickets_path(conference)
      expect(page).to have_content 'Tickets'
      fill_in "tickets__#{conference.tickets.second.id}", with: 3
      click_button 'Continue'
      expect(current_path).to eq new_conference_payment_path(conference)
    end

    scenario 'without tickets', feature: true, js: true do
      visit conference_tickets_path(conference)
      expect(page).to have_content 'Tickets'
      click_button 'Continue'
      expect(current_path).to eq conference_tickets_path(conference)
      expect(flash).to eq 'Please get at least one ticket to continue.'
    end
  end

  context 'user buys ticket with offline payment' do
    before(:each) do
      sign_in user
    end

    scenario 'once', feature: true, js: true do
      expected_payment_count = Payment.count + 1

      visit conference_tickets_path(conference)
      expect(page).to have_content 'Tickets'
      fill_in "tickets__#{ticket.id}", with: 3
      click_button 'Offline Payment'

      expect(current_path).to eq conference_payments_path(conference)
      expect(Payment.count).to eq expected_payment_count
      expect(user.ticket_purchases.count).to eq 1
      expect(user.ticket_purchases.first.paid).to eq false
    end

    scenario 'twice', feature: true, js: true do
      expected_payment_count = Payment.count + 1

      visit conference_tickets_path(conference)
      expect(page).to have_content 'Tickets'
      fill_in "tickets__#{ticket.id}", with: 3
      click_button 'Offline Payment'

      expect(current_path).to eq conference_payments_path(conference)
      expect(Payment.count).to eq expected_payment_count
      expect(user.payments.last.status).to eq 'unpaid'
      expect(user.ticket_purchases.count).to eq 1
      expect(user.ticket_purchases.first.paid).to eq false

      expected_payment_count = Payment.count + 1
      visit conference_tickets_path(conference)
      expect(page).to have_content 'Tickets'
      fill_in "tickets__#{second_ticket.id}", with: 2
      click_button 'Offline Payment'
      expect(Payment.count).to eq expected_payment_count
      expect(user.payments.last.status).to eq 'unpaid'
      expect(user.ticket_purchases.count).to eq 2
      expect(user.ticket_purchases.first.paid).to eq false
      expect(user.payments.last.ticket_purchases).to eq [user.ticket_purchases.second]
    end
  end
end
