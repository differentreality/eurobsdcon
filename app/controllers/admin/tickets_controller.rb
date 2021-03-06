# frozen_string_literal: true

module Admin
  class TicketsController < Admin::BaseController
    load_and_authorize_resource :conference, find_by: :short_title
    load_and_authorize_resource :ticket, through: :conference

    def index
      authorize! :update, Ticket.new(conference_id: @conference.id)
      @tickets_sold_distribution = @conference.tickets_sold_distribution
      @tickets_turnover_distribution = @conference.tickets_turnover_distribution
    end

    def new
      existing_ticket = @conference.tickets.find_by(id: params[:ticket_id])
      @ticket = existing_ticket.dup || @conference.tickets.new
      @ticket.event = existing_ticket.try(:event)
      @ticket.dependent = existing_ticket.try(:dependent)
    end

    def create

      @ticket = @conference.tickets.new(ticket_params)
      if @ticket.save(ticket_params)
        redirect_to admin_conference_tickets_path(conference_id: @conference.short_title),
                    notice: 'Ticket successfully created.'
      else
        flash.now[:error] = "Creating Ticket failed: #{@ticket.errors.full_messages.join('. ')}."
        render :new
      end
    end

    def edit; end

    def update
      if @ticket.update_attributes(ticket_params)
        redirect_to admin_conference_tickets_path(conference_id: @conference.short_title),
                    notice: 'Ticket successfully updated.'
      else
        flash.now[:error] = "Ticket update failed: #{@ticket.errors.full_messages.join('. ')}."
        render :edit
      end
    end

    def destroy
      if @ticket.coupons.any?
        redirect_to admin_conference_tickets_path(conference_id: @conference.short_title),
                    error: 'The ticket is used in coupons, and cannot be destroyed' and return
      end

      if @ticket.destroy
        redirect_to admin_conference_tickets_path(conference_id: @conference.short_title),
                    notice: 'Ticket successfully destroyed.'
      else
        redirect_to admin_conference_tickets_path(conference_id: @conference.short_title),
                    error: 'Ticket could not be destroyed.' \
                    "#{@ticket.errors.full_messages.join('. ')}."
      end
    end

    private

    def ticket_params
      params.require(:ticket).permit(:title, :url, :description,
                                     :start_date, :end_date,
                                     :price, :price_cents, :price_currency,
                                     :registration_ticket,
                                     :ticket_group_id,
                                     :dependent_id,
                                     :event_id,
                                     :conference_id)
    end
  end
end
