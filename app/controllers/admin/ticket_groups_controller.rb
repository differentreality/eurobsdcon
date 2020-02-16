# frozen_string_literal: true

module Admin
  class TicketGroupsController < Admin::BaseController
    load_and_authorize_resource :conference, find_by: :short_title
    load_and_authorize_resource :ticket_group, through: :conference

    # GET /admin/ticket_groups
    def index
      @ticket_groups = @conference.ticket_groups.all
    end

    # GET /admin/ticket_groups/1
    def show
    end

    # GET /admin/ticket_groups/new
    def new
      @ticket_group = @conference.ticket_groups.new(vat_percent: ENV['TICKET_GROUP_VAT_PERCENT'])
    end

    # GET /admin/ticket_groups/1/edit
    def edit
    end

    # POST /admin/ticket_groups
    def create
      @ticket_group = @conference.ticket_groups.new(ticket_group_params)

      if @ticket_group.save
        redirect_to admin_conference_ticket_groups_path(@conference), notice: 'Ticket group was successfully created.'
      else
        render :new
      end
    end

    # PATCH/PUT /admin/ticket_groups/1
    def update
      if @ticket_group.update(ticket_group_params)
        redirect_to @ticket_group, notice: 'Ticket group was successfully updated.'
      else
        render :edit
      end
    end

    # DELETE /admin/ticket_groups/1
    def destroy
      @ticket_group.destroy
      redirect_to admin_conference_ticket_groups_path(@conference), notice: 'Ticket group was successfully destroyed.'
    end

    private

      # Only allow a trusted parameter "white list" through.
      def ticket_group_params
        params.require(:ticket_group).permit(:name, :vat_percent)
      end
  end
end
