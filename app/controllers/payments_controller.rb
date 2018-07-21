# frozen_string_literal: true

class PaymentsController < ApplicationController
  require 'paymill'
  before_action :authenticate_user!
  load_and_authorize_resource
  load_resource :conference, find_by: :short_title
  authorize_resource :conference_registrations, class: Registration

  def index
    @payments = current_user.payments
  end

  def new
    @total_amount_to_pay = Ticket.total_price(@conference, current_user, paid: false)
    @total_amount_to_pay = @total_amount_to_pay - current_user.overall_discount(@conference, @total_amount_to_pay)

    if @total_amount_to_pay.zero?
      raise CanCan::AccessDenied.new('Nothing to pay for!', :new, Payment)
    end
    @user_registration = current_user.registrations.for_conference @conference
    @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference)
    @overall_discount_percent = params[:overall_discount_percent]
    @overall_discount_value = params[:overall_discount_value]
  end

  def create
    @payment = Payment.new payment_params
    registration_survey = @conference.surveys.during_registration.select(&:active?)
    redirect_path = if registration_survey.any?
                      if current_user.survey_submissions.where(survey: registration_survey.first).any?
                        conference_conference_registration_path(@conference)
                        else
                          conference_survey_path(@conference, registration_survey.first)
                        end
                      else
                        conference_conference_registration_path(@conference)
                      end

    if ENV['PAYMILL_PRIVATE_API_KEY'].present?
      Paymill.api_key = ENV['PAYMILL_PRIVATE_API_KEY']
      begin
        token = params['token']

        paymill_response = Paymill::Transaction.create amount: @payment.amount,
                             currency: @conference.tickets.first.price_currency,
                             token: token,
                             description: "#{@conference.short_title} -  Registration ID #{current_user.registrations.find_by(conference: @conference).try(:id)}"
        @payment.authorization_code = paymill_response.id
        @payment.last4 = paymill_response.payment.id
      rescue => e
         @total_amount_to_pay = Ticket.total_price(@conference, current_user, paid: false)
         @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference)
         Rails.logger.info "An error occured during payment for user #{current_user.email}. This is the error message: #{e.message}"
         error = if e.message['response_code'] == 51200
                   error = 'Unfortunately we could not process your payment. Your bank has rejected the transaction.'
                else
                  error = "An error occured while processing your payment. Please try again or contact the organizers."
                end
         flash[:error] = error
         render :new
         return
      end
      if @payment.save
        update_purchased_ticket_purchases
        @payment.update_attributes(status: 'success')
        flash[:notice] = 'Ticket(s) successfully booked. Thank you!'
        redirect_to redirect_path || :back
        return
      else
        @total_amount_to_pay = Ticket.total_price(@conference, current_user, paid: false)
        @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference)
        flash.now[:error] = @payment.errors.full_messages.to_sentence + ' Please try again with correct credentials.'
        render :new
        return
      end
    end

    if @payment.purchase && @payment.save
      update_purchased_ticket_purchases
      redirect_to conference_physical_tickets_path,
                  notice: 'Thanks! Your ticket is booked successfully.'
    else
      @total_amount_to_pay = Ticket.total_price(@conference, current_user, paid: false)
      @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference)
      flash.now[:error] = @payment.errors.full_messages.to_sentence + ' Please try again with correct credentials.'
      render :new
    end
  end

  private

  def payment_params
    if ENV['PAYMILL_PRIVATE_API_KEY'].present?
      params.require(:payment).permit(:amount, :overall_discount).merge(conference: @conference,
                                                     user: current_user)
    else
      params.permit(:stripe_customer_email, :stripe_customer_token)
            .merge(stripe_customer_email: params[:stripeEmail],
                   stripe_customer_token: params[:stripeToken],
                   user: current_user, conference: @conference)
    end
  end

  def update_purchased_ticket_purchases
    current_user.ticket_purchases.by_conference(@conference).unpaid.each do |ticket_purchase|
      ticket_purchase.pay(@payment)
    end
  end
end
