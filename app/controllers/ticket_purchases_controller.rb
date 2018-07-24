# frozen_string_literal: true

class TicketPurchasesController < ApplicationController
  before_action :authenticate_user!
  load_resource :conference, find_by: :short_title
  authorize_resource :conference_registrations, class: Registration
  authorize_resource

  def create
    current_user.ticket_purchases.by_conference(@conference).unpaid.destroy_all
    message = TicketPurchase.purchase(@conference, current_user, params[:tickets].try(:first))
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
      elsif current_user.ticket_purchases.by_conference(@conference).paid.any?
        flash[:notice] = 'Ticket(s) successfully booked!'
        redirect_to redirect_path
      else
        redirect_to conference_tickets_path(@conference.short_title),
                    error: 'Please get at least one ticket to continue.'
      end
    else
      redirect_to conference_tickets_path(@conference.short_title, tickets: params[:tickets].try(:first)),
                  error: "Oops, something went wrong with your purchase! #{message.join('. ')}"
    end
  end

  def index
    @unpaid_ticket_purchases = current_user.ticket_purchases.by_conference(@conference).unpaid
  end

  private

  def ticket_purchase_params
    params.require(:ticket_purchase).permit(:ticket_id, :user_id, :conference_id, :quantity)
  end
end
