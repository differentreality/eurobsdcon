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
        redirect_to conference_conference_registration_path(@conference)
      else
        raise CanCan::AccessDenied.new('Nothing to pay for!', :new, Payment)
      end
    end
    @user_registration = current_user.registrations.for_conference @conference

    @overall_discount_percent = params[:overall_discount_percent]
    @overall_discount_value = params[:overall_discount_value]
    @url = conference_payments_path(@conference)
  end

  def edit
    @total_amount_to_pay = Money.new(@payment.amount, @conference.tickets.first.price_currency)
    @unpaid_ticket_purchases = @payment.ticket_purchases
    @user_registration = current_user.registrations.for_conference @conference
  end

  def create
    @payment = Payment.new payment_params

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
