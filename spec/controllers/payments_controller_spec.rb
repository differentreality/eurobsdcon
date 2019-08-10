# frozen_string_literal: true

require 'spec_helper'

describe PaymentsController do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }

  let!(:conference) { create(:conference, start_date: Date.current - 1.day, end_date: Date.current + 1.day, timezone: Time.current.zone) }
  let!(:survey_future) { create(:survey, surveyable: conference, start_date: Date.current + 2.days, end_date: Date.current + 3.days, target: 'during_registration') }
  let!(:survey_past) { create(:survey, surveyable: conference, start_date: Date.current - 1.day, end_date: Date.current - 1.day, target: 'after_conference') }
  let!(:survey_present) { create(:survey, surveyable: conference, start_date: Date.current - 1.day, end_date: Date.current + 1.day, target: 'during_registration') }
  let!(:user_payment) { create(:payment, user: user, conference: conference) }
  let!(:payment) { create(:payment) }
  let(:ticket1) { create(:ticket, conference: conference, price_cents: 1000) }
  let(:ticket2) { create(:ticket, conference: conference) }
  let!(:user_registration) { create(:registration, user: user, conference: conference) }

  let(:conference_without_survey) { create(:conference) }

  describe 'GET #index' do
    before { sign_in user }
    before { get :index, params: { conference_id: conference.short_title } }

    it 'assigns payments variable' do
      expect(assigns(:payments)).to eq [user_payment]
    end

    it 'renders index template' do
      expect(response).to render_template('index')
    end
  end

  describe 'GET #new' do
    before { sign_in user }

    context 'without tickets' do
      before { get :new, params: { conference_id: conference.short_title } }
      it 'redirects to root_path' do
        expect(response).to redirect_to root_path
        expect(flash['alert']).to eq 'Nothing to pay for!'
      end

      it 'sets amount to 0' do
        expect(assigns(:total_amount_to_pay)).to eq 0
      end
    end

    context 'with tickets without discount' do
      before :each do
        @ticket_purchase = create(:ticket_purchase, ticket: ticket1, conference: conference, paid: false, user: user)
        get :new, params: { conference_id: conference.short_title }
      end

      it 'sets variables' do
        expect(assigns(:total_amount_to_pay)).to eq Money.new(10000, 'USD')
        expect(assigns(:user_registration)).to eq user_registration
        expect(assigns(:unpaid_ticket_purchases)).to eq [@ticket_purchase]
      end

      it 'renders new template' do
        expect(response).to render_template('new')
      end
    end

    context 'with tickets and with discount' do
    end
  end

  # edit action exists only if we have offline payments made
  describe 'GET #edit' do
    before :each do
      sign_in user
      @offline_payment = create(:payment, user: user, conference: conference, amount: 350)
      @user_ticket_purchase = create(:ticket_purchase, user: user,conference: conference, paid: false, ticket: create(:ticket, price_cents: 35000), payment: @offline_payment)
      user.reload
      get :edit, params: { conference_id: conference.short_title, id: @offline_payment.id }
    end

    it 'sets variables' do
      expect(assigns(:total_amount_to_pay)).to eq Money.new(350, 'USD')
      expect(assigns(:unpaid_ticket_purchases)).to eq [@user_ticket_purchase]
      # expect(assigns(:url)).to eq update_paymill_conference_payment_path(conference, @offline_payment)
    end
  end

  describe 'GET #offline_payment' do
    before { sign_in user }
    before { get :offline_payment, params: { conference_id: conference.short_title, tickets: [ {ticket1.id => 3, ticket2.id => 5} ] } }

    it 'redirects to payments#index' do
      expect(flash[:alert]).to eq nil
      expect(response).to redirect_to conference_payments_path(conference)
    end

    it 'does not create physical tickets' do
      expected = expect do
                   get :offline_payment, params: { conference_id: conference.short_title, tickets: [ {ticket1.id => 3, ticket2.id => 5} ] }
                 end
      expected.to change { PhysicalTicket.count }.by(0)
    end
  end
end
