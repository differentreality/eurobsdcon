# frozen_string_literal: true

class PaymentsController < ApplicationController
  require 'paymill'
  before_action :authenticate_user!
  load_and_authorize_resource
  load_resource :conference, find_by: :short_title
  authorize_resource :conference_registrations, class: Registration

  def index
    @payments = @conference.payments.where(user: current_user)
  end

  def new
    @total_amount_to_pay = Ticket.total_price(@conference, current_user, paid: false, payment: nil)
    @total_amount_to_pay = @total_amount_to_pay - current_user.overall_discount(@conference, @total_amount_to_pay)

    if @total_amount_to_pay.zero?
      raise CanCan::AccessDenied.new('Nothing to pay for!', :new, Payment)
    end
    @user_registration = current_user.registrations.for_conference @conference
    @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference).where(payment: nil)
    @overall_discount_percent = params[:overall_discount_percent]
    @overall_discount_value = params[:overall_discount_value]
    @url = conference_payments_path(@conference)
  end

  def edit
    @total_amount_to_pay = Money.new(@payment.amount, @conference.tickets.first.price_currency)
    @unpaid_ticket_purchases = @payment.ticket_purchases
    @user_registration = current_user.registrations.for_conference @conference
    @url = update_paymill_conference_payment_path(@conference, @payment)
  end

  def update_paymill
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
        @payment.status = 'success'
       rescue => e
         @total_amount_to_pay = Ticket.total_price(@conference, current_user, paid: false, payment: @payment)
         @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference).where(payment: @payment)
         Rails.logger.info "An error occured during payment for user #{current_user.email}. This is the error message: #{e.message}"
         error = if e.message['response_code'] == 51200
                   error = 'Unfortunately we could not process your payment. Your card issuer has rejected the transaction. Please make sure you allow pop ups and try again, or contact your card issuer.'
                else
                  error = "An error occured while processing your payment. Please try again or contact the organizers."
                end
         flash[:error] = error

         render :edit
         return
       end

      if @payment.save
        update_purchased_ticket_purchases(@payment)
        # @payment.update_attributes(status: 'success')
        flash[:notice] = 'Ticket(s) successfully booked. Thank you!'
        redirect_to redirect_path || :back
        return
      else
        @total_amount_to_pay = Ticket.total_price(@conference, current_user, paid: false, payment: @payment)
        @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference).where(payment: @payment)
        flash.now[:error] = @payment.errors.full_messages.to_sentence + ' Please try again with correct credentials.'
        render :edit
        return
      end
    end

  end

  def create
    @payment = Payment.new payment_params

    if ENV['PAYMILL_PRIVATE_API_KEY'].present?
      Paymill.api_key = ENV['PAYMILL_PRIVATE_API_KEY']
      begin
        token = params['token']

        @paymill_response = Paymill::Transaction.create amount: @payment.amount,
                             currency: @conference.tickets.first.price_currency,
                             token: token,
                             description: "#{@conference.short_title} -  Registration ID #{current_user.registrations.find_by(conference: @conference).try(:id)}"
        @payment.authorization_code = @paymill_response.id
        @payment.last4 = @paymill_response.payment.id
       rescue => e
         @total_amount_to_pay = Ticket.total_price(@conference, current_user, paid: false, payment: nil)
         @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference).where(payment: nil)
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
        @total_amount_to_pay = Ticket.total_price(@conference, current_user, paid: false, payment: nil)
        @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference).where(payment: nil)
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
      @total_amount_to_pay = Ticket.total_price(@conference, current_user, paid: false, payment: nil)
      @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference)
      flash.now[:error] = @payment.errors.full_messages.to_sentence + ' Please try again with correct credentials.'
      render :new
    end
  end

  def offline_payment
    # message = TicketPurchase.purchase(@conference, user, params[:tickets].try(:first))
    purchases = params[:tickets].try(:first)

    ActiveRecord::Base.transaction do
      @conference.tickets.each do |ticket|
        quantity = purchases[ticket.id.to_s].to_i

        # if the user bought the ticket and is still unpaid, just update the quantity
        purchase = if ticket.bought?(current_user) && ticket.unpaid?(current_user)
                     TicketPurchase.update_quantity(@conference, quantity, ticket, current_user)
                   else
                     TicketPurchase.purchase_ticket(@conference, quantity, ticket, current_user)
                   end
        if purchase && !purchase.save
          errors.push(purchase.errors.full_messages)
        end
      end
    end
    # Create payment
    @payment = @conference.payments.new#(payment_params)
    @total_amount_to_pay = Ticket.total_price(@conference, current_user, paid: false, payment: nil)
    @total_amount_to_pay = @total_amount_to_pay - current_user.overall_discount(@conference, @total_amount_to_pay)

    @payment.amount = @total_amount_to_pay * 100.0 # params[:payment][:amount].to_f * 100.0

    @payment.user = current_user
    @payment.status = 0

    if @payment.save
      # create physical tickets
      current_user.ticket_purchases.where(payment: nil).by_conference(@conference).unpaid.each do |ticket_purchase|
        ticket_purchase.payment = @payment
        ticket_purchase.save
      end
    end

    redirect_to conference_payments_path(@conference)
  end

  private

  def redirect_path
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
    redirect_path
  end

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

  def update_purchased_ticket_purchases(payment=nil)
    current_user.ticket_purchases.by_conference(@conference).unpaid.where(payment: payment).each do |ticket_purchase|
      ticket_purchase.pay(@payment)
    end
  end
end
