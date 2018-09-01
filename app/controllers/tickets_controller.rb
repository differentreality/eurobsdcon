# frozen_string_literal: true

class TicketsController < ApplicationController
  before_action :authenticate_user!
  load_resource :conference, find_by: :short_title
  load_resource :ticket, through: :conference
  load_resource :payment, only: :index
  authorize_resource :conference_registrations, class: Registration
  before_action :check_load_resource, only: :index

  def index
    @user_registration = current_user.registrations.for_conference @conference
    @registration = @user_registration
    @selection = if params[:show_unpaid_ticket_purchases]
                   current_user.ticket_purchases.unpaid.by_conference(@conference).where(payment: @payment).map{ |tp| [tp.ticket_id, tp.quantity] }.compact.to_h
                 elsif params[:tickets]
                   params[:tickets].map{|k, v| [k.to_i, v.to_i] if v.to_i > 0 }.compact.to_h
                 end

    @overall_discount_percent = current_user.overall_discount_percent(@conference)
    @overall_discount_value = current_user.overall_discount_value(@conference)
  end

  def check_load_resource
    if @tickets.empty?
      redirect_to root_path, notice: "There are no tickets available for #{@conference.title}!"
    end
  end
end
