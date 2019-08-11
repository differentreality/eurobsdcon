# frozen_string_literal: true

require 'spec_helper'

describe Admin::PaymentsController do
  let!(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:conference) { create(:conference) }
  let!(:payment) { create(:payment, conference: conference) }
  let!(:other_payment) { create(:payment) }
  let(:ticket1) { create(:ticket, conference: conference) }
  let(:ticket2) { create(:ticket, conference: conference) }

  context 'admin is signed in' do
    before { sign_in admin }

    describe 'GET #index' do
      before { get :index, params: { conference_id: conference.short_title, tickets: [ {ticket1.id => 3, ticket2.id => 5} ] } }

      it 'assigns payments variable' do
        expect(assigns(:conference)).to eq conference
        expect(assigns(:payments)).to eq [payment]
      end

      it 'renders index template' do
        expect(response).to render_template('index')
      end
    end

    describe 'GET #edit' do
      before { get :edit, params: { conference_id: conference.short_title, id: payment.id } }

      it 'renders edit template' do
        expect(response).to render_template('edit')
      end

      it 'assigns payment variable' do
        expect(assigns(:payment)).to eq payment
      end
    end

    describe 'GET #new' do
      before { get :new, params: { conference_id: conference.short_title, user_id: user.id } }

      it 'renders new template' do
        expect(response).to render_template('new')
      end

      it 'assigns payment variable' do
        expect(assigns(:payment)).to be_instance_of(Payment)
      end

      it 'assigns user variable' do
        expect(assigns(:user)).to eq user
      end
    end

    # describe 'POST #create' do
    #   context 'saves successfuly' do
    #     before do
    #       post :create, payment: attributes_for(:payment), conference_id: conference.short_title
    #     end
    #
    #     it 'redirects to admin payment index path' do
    #       expect(response).to redirect_to admin_conference_payments_path(conference_id: conference.short_title)
    #     end
    #
    #     it 'shows success message in flash notice' do
    #       expect(flash[:notice]).to match('payment successfully created.')
    #     end
    #
    #     it 'creates new payment' do
    #       expect(payment.count).to eq 1
    #     end
    #   end
    #
    #   context 'save fails' do
    #     before do
    #       allow_any_instance_of(payment).to receive(:save).and_return(false)
    #       post :create, payment: attributes_for(:payment), conference_id: conference.short_title
    #     end
    #
    #     it 'renders new template' do
    #       expect(response).to render_template('new')
    #     end
    #
    #     it 'shows error in flash message' do
    #       expect(flash[:error]).to match("Creating payment failed: #{payment.errors.full_messages.join('. ')}.")
    #     end
    #
    #     it 'does not create new payment' do
    #       expect(payment.count).to eq 0
    #     end
    #   end
    # end

    describe 'PATCH #update' do
      context 'updates successfully' do
        before do
          patch :update, params: { payment: attributes_for(:payment, last4: '6868'),
                                  conference_id: conference.short_title,
                                  id: payment.id }
        end

        it 'redirects to admin payments index path' do
          expect(response).to redirect_to admin_conference_payments_path(conference_id: conference.short_title)
        end

        it 'shows success message in flash notice' do
          expect(flash[:notice]).to match('Payment updated successfuly')
        end

        it 'updates the payment' do
          payment.reload
          expect(payment.last4).to eq '6868'
        end
      end

      context 'update fails' do
        before do
          allow_any_instance_of(Payment).to receive(:save).and_return(false)
          patch :update, params: { payment: attributes_for(:payment, last4: '6868'),
                                   conference_id: conference.short_title,
                                   id: payment.id }
        end

        it 'renders edit template' do
          expect(response).to render_template('edit')
        end

        it 'shows error in flash message' do
          expect(flash[:error]).to match("Could not update payment. #{payment.errors.full_messages.to_sentence}")
        end

        it 'does not update payment' do
          payment.reload
          expect(payment.last4).to eq '0000'
        end
      end
    end
  end
end
