# frozen_string_literal: true

class TicketPurchasesController < ApplicationController
  before_action :authenticate_user!
  load_resource :conference, find_by: :short_title
  authorize_resource :conference_registrations, class: Registration
  authorize_resource

  def create
    if params['offline']
      redirect_to conference_payments_offline_payment_path(@conference, tickets: params[:tickets])
      return
    end
    current_user.ticket_purchases.by_conference(@conference).unpaid.where(payment: nil).destroy_all
    # Tickets param needs to be .to_h due to Rails prohibiting hash methods on params
    message = TicketPurchase.purchase(@conference, current_user, ticket_purchase_params[:tickets].to_h)
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
    if message.blank?
      if current_user.ticket_purchases.by_conference(@conference).unpaid.any?
        redirect_to new_conference_payment_path(overall_discount: params[:overall_discount]),
                    notice: 'Please pay here to get the tickets.'
        return
      elsif current_user.ticket_purchases.by_conference(@conference).paid.any?
        flash[:notice] = 'Ticket(s) successfully booked!'
        redirect_to redirect_path
        return
      else
        redirect_to conference_tickets_path(@conference.short_title),
                    error: 'Please get at least one ticket to continue.'
        return
      end
    else
      redirect_to conference_tickets_path(@conference.short_title, tickets: ticket_purchase_params[:tickets].to_h),
                  error: "Oops, something went wrong with your purchase! #{message.join('. ')}"
      return
    end
  end

  def index
    @unpaid_ticket_purchases = current_user.ticket_purchases.by_conference(@conference).unpaid
  end

  private

  def ticket_purchase_params
    params.require(:ticket_purchase).permit(:ticket_id, :user_id, :conference_id, :quantity, tickets: {})
  end
end
