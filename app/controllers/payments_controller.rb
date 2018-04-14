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
    if @total_amount_to_pay.zero?
      raise CanCan::AccessDenied.new('Nothing to pay for!', :new, Payment)
    end
    @unpaid_ticket_purchases = current_user.ticket_purchases.unpaid.by_conference(@conference)
  end

  def create
    @payment = Payment.new payment_params

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
         flash[:error] = "An error occured while processing your payment. #{e.message}"
         render :new
         return
       end
      if @payment.save
        update_purchased_ticket_purchases
        redirect_to conference_physical_tickets_path,
                    notice: 'Thanks! Your ticket is booked successfully.'
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
      params.require(:payment).permit(:amount).merge(conference: @conference,
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
