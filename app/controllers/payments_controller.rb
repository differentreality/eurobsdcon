# frozen_string_literal: true

class PaymentsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource
  load_resource :conference, find_by: :short_title
  authorize_resource :conference_registrations, class: Registration

  def index
    @payments = @conference.payments.where(user: current_user).order(created_at: :desc)
  end

  def new
    @payment = @conference.payments.new(user: current_user)
    @total_amount_to_pay = Ticket.total_price(@conference, current_user, paid: false, payment: nil)
    overall_discount = current_user.overall_discount(@conference, @total_amount_to_pay)
    @total_amount_to_pay = @total_amount_to_pay - overall_discount

    @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference).where(payment: nil)
    # if @total_amount_to_pay.zero? and ticket purchases exist, mark them as paid

    if @total_amount_to_pay.zero?
      if @unpaid_ticket_purchases.any?
        # Create payment with 0 amount
        payment = @conference.payments.create(user: current_user, amount: 0, status: 'success', overall_discount: overall_discount)
        @unpaid_ticket_purchases.each do |purchase|
          purchase.pay(payment)
        end
        flash[:notice] = 'Ticket(s) successfully booked!'
        redirect_to conference_conference_registration_path(@conference) and return
      else
        raise CanCan::AccessDenied.new('Nothing to pay for!', :new, Payment)
      end
    end

    @user_registration = current_user.registrations.for_conference @conference

    intent = @payment.create_intent(@total_amount_to_pay)

    @intent_secret = intent.client_secret
    # @overall_discount_percent = params[:overall_discount_percent]
    # @overall_discount_value = params[:overall_discount_value]
    @url = conference_payments_path(@conference)
  end

  def edit
    @total_amount_to_pay = Money.new(@payment.amount, @conference.tickets.first.price_currency)
    @unpaid_ticket_purchases = @payment.ticket_purchases
    @user_registration = current_user.registrations.for_conference @conference
    intent = @payment.stripe_payment_details || @payment.create_intent(@total_amount_to_pay)
    @intent_secret = intent.client_secret
    @url = conference_payment_path(@conference, @payment)
  end

  def update
    # Successful transaction
    if params['payment_result'] && params['payment_result']['paymentIntent']
      transaction_status = 'success'
      intent = params['payment_result']['paymentIntent']
      @payment.authorization_code = intent['id']
      @payment.amount = intent['amount']
      payment_details = @payment.stripe_payment_details
      last4 = payment_details.charges.data.first.payment_method_details.card.last4

    # Validation error for missing payment information
    elsif params['payment_result']['error']['type'] == 'validation_error'
      transaction_message = params['payment_result']['error']['message']
      flash[:error] = 'There was a problem with the payment information you provided. ' + transaction_message
      return

    # Failed transaction  -  When is this reached?
    elsif params['payment_result']['error']['type'] == 'invalid_request_error'
      transaction_status = 'failure'
      intent = params['payment_result']['error']['payment_intent']

      @payment.amount = intent['amount']
      @payment.authorization_code = intent['id']

      # We may have an error due to wrong cc no, so there is no actual charge try
      last4 = params['payment_result']['error']['payment_method']['card']['last4'] if params['payment_result']['error']['payment_method']

    else # Should I save this payment with failed transaction or not?
      flash[:error] = 'There was a problem with your payment. Please try again or contact the organizers.'
      return
    end

    @payment.status = transaction_status
    @payment.last4 = last4

    if @payment.save
      if @payment.status == 'success'

        respond_to do |format|
          format.html { redirect_to redirect_path }
          format.js {
            flash.clear
            flash.keep[:notice] = 'Thanks! Your payment was successful.'
            render js: "window.location='#{redirect_path}'" }
        end
      else
        flash.now[:error] = 'Sorry, something went wrong with your payment. Please try paying again.'

        respond_to do |format|
          format.html { redirect_to redirect_path }
          format.js
        end
      end

    else # Payment not saved
      if transaction_status == 'success'
        Rails.logger.error "\n\nError in payments! \nATTENTION: Failed to save payment, with a successful transaction. The transaction was successful, the card has been charged, but OSEM could not save the payment. The payment was not saved due to the following errors: \n #{@payment.errors.full_messages.to_sentence}
        \nRelevant purchases: #{current_user.ticket_purchases.by_conference(@conference).unpaid.where(payment: nil).inspect}\n\n"

        # Since the payment has been done (charge has been made through Stripe), even though we could not save it
        # Mark relevant purchases as paid // Ticket purchases paid, no payment available
        # KEEP THE FOLLOWING LINE AFTER THE ERROR MESSAGE WHICH MENTIONS THE RELEVANT TICKET PURCHASES!
        update_purchased_ticket_purchases

        @error_flash_message = "Your payment was successful, but there was an error while saving the details. We apologize for the invonvenience. Please contact the organizers via #{@conference.contact.email}"

        flash.keep[:error] = @error_flash_message
        @intent_secret = params[:intent_id]
        respond_to do |format|
          format.html
          format.js {
            render js: "window.location='#{redirect_path}'"
           }
        end
      # else block is not possible (failed transaction and failed save), it is never reached.
      # We never reach the save block, if the transaction has failed.
      # We check the failed transaction result before saving Payment
      # and we show the relevant flash message and return!
      end
    end
  end

  def create
    @payment = @conference.payments.new

    # Successful transaction
    if params['payment_result'] && params['payment_result']['paymentIntent']
      transaction_status = 'success'
      intent = params['payment_result']['paymentIntent']
      @payment.authorization_code = intent['id']
      @payment.amount = intent['amount']
      payment_details = @payment.stripe_payment_details
      last4 = payment_details.charges.data.first.payment_method_details.card.last4

    # Validation error for missing payment information
    elsif params['payment_result']['error']['type'] == 'validation_error'
      transaction_message = params['payment_result']['error']['message']
      flash[:error] = 'There was a problem with the payment information you provided. ' + transaction_message
      return

    # Transaction failed by Stripe
    elsif params['payment_result']['error']['type'] == 'invalid_request_error'
      transaction_status = 'failure'
      intent = params['payment_result']['error']['payment_intent']

      @payment.amount = intent['amount']
      @payment.authorization_code = intent['id']
      # We may have an error due to wrong cc no, so there is no actual charge try
      last4 = params['payment_result']['error']['payment_method']['card']['last4'] if params['payment_result']['error']['payment_method']

    else # Should I save this payment with failed transaction or not?
      transaction_status = 'failure'
      flash[:error] = 'There was a problem with your payment. Please try again or contact the organizers.'
      return
    end

    @payment.status = transaction_status
    @payment.last4 = last4
    @payment.user = current_user

    if @payment.save
      update_purchased_ticket_purchases

      if @payment.status == 'success'
        update_purchased_ticket_purchases(@payment)
        flash.clear
        flash.keep[:notice] = 'Thanks! Your payment was successful.'

        respond_to do |format|
          format.html { redirect_to redirect_path }
          format.js {
            render js: "window.location='#{redirect_path}'" }
        end
      else
        flash.keep[:error] = 'Sorry, something went wrong with your payment. Please go to your payments page and try paying again, or contact the organizers.'

        respond_to do |format|
          format.html { redirect_to redirect_path }
          format.js {
            render js: "window.location='#{redirect_path}'"
          }
        end
      end
    else
      # Payment has succeeded, but Payment couldn't be saved
      # @total_amount_to_pay = Ticket.total_price(@conference, current_user, paid: false, payment: nil)
      # @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference)

      if transaction_status == 'success'
        Rails.logger.error "\n\nError in payments! \nATTENTION: Failed to save payment, with a successful transaction. The transaction was successful, the card has been charged, but OSEM could not save the payment. The payment was not saved due to the following errors: \n #{@payment.errors.full_messages.to_sentence}
        \nRelevant purchases: #{current_user.ticket_purchases.by_conference(@conference).unpaid.where(payment: nil).inspect}\n\n"

        # Since the payment has been done (charge has been made through Stripe), even though we could not save it
        # Mark relevant purchases as paid // Ticket purchases paid, no payment available
        # KEEP THE FOLLOWING LINE AFTER THE ERROR MESSAGE WHICH MENTIONS THE RELEVANT TICKET PURCHASES!
        update_purchased_ticket_purchases

        @error_flash_message = "Your payment was successful, but there was an error while saving the details. We apologize for the invonvenience. Please contact the organizers via #{@conference.contact.email}"

        flash.keep[:error] = @error_flash_message
        @intent_secret = params[:intent_id]
        respond_to do |format|
          format.html #{ redirect_to new_conference_payment_path(@conference) and return }
          format.js {
            render js: "window.location='#{redirect_path}'"
           }
        end
      # else block is not possible (failed transaction and failed save)
      # because it is never reached
      # We never reach the save block, if the transaction has failed.
      # We check the failed transaction result before saving Payment
      # and we show the relevant flash message and return!
      end
    end
  end

  def offline_payment
    # message = TicketPurchase.purchase(@conference, user, params[:tickets].try(:first))
    purchases = params[:ticket_purchases] ? params[:ticket_purchases][:tickets] : {}
    if purchases.empty?
      redirect_to conference_tickets_path(@conference.short_title)
      return
    end
    errors = []

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
          Rails.logger.debug "An error occurred while trying to save purchase ID#{purchase.id} with errors: #{errors.compact.join('. ')}"
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
    @redirect_path = if registration_survey.any?
                       if current_user.survey_submissions.where(survey: registration_survey.first).any?
                         conference_conference_registration_path(@conference)
                       else
                         conference_survey_path(@conference, registration_survey.first)
                       end
                     else
                       conference_conference_registration_path(@conference)
                     end
    # Used in create.js.erb file because
    # during payment process we have an ajax call which redirects to path
    @redirect_path
  end

  def payment_params
    params.permit(:stripe_customer_email, :stripe_customer_token)
          .merge(stripe_customer_email: params[:stripeEmail],
                 stripe_customer_token: params[:stripeToken],
                 user: current_user, conference: @conference)
  end

  def update_purchased_ticket_purchases(payment=nil)
    current_user.ticket_purchases.by_conference(@conference).unpaid.where(payment: payment).each do |ticket_purchase|
      ticket_purchase.pay(@payment)
    end
  end
end
