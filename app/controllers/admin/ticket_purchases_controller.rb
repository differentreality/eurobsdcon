module Admin
  class TicketPurchasesController < Admin::BaseController
    load_and_authorize_resource :conference, find_by: :short_title
    load_and_authorize_resource through: :conference
    load_resource :user

    def create
      unless @user
        redirect_to admin_conference_payments_path(@conference), error: 'Could not find user'
      end

      @user.ticket_purchases.by_conference(@conference).unpaid.destroy_all
      # message = TicketPurchase.purchase(@conference, user, params[:tickets].try(:first))
      purchases = params[:tickets].try(:first)

      ActiveRecord::Base.transaction do
        @conference.tickets.each do |ticket|
          quantity = purchases[ticket.id.to_s].to_i
          # if the user bought the ticket and is still unpaid, just update the quantity
          purchase = if ticket.bought?(@user) && ticket.unpaid?(@user)
                       TicketPurchase.update_quantity(@conference, quantity, ticket, @user)
                     else
                       TicketPurchase.purchase_ticket(@conference, quantity, ticket, @user)
                     end
          if purchase && !purchase.save
            errors.push(purchase.errors.full_messages)
          end
        end
      end
      # Create payment

      @payment = @conference.payments.new(payment_params)
      @payment.amount = params[:payment][:amount].to_f * 100.0

      @payment.user = @user
      @payment.status = 1

      if @payment.save
        # create physical tickets
        @user.ticket_purchases.by_conference(@conference).unpaid.each do |ticket_purchase|
          ticket_purchase.pay(@payment)
        end
      end

      redirect_to admin_conference_payments_path(@conference)
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
      if @ticket.destroy
        redirect_to admin_conference_tickets_path(conference_id: @conference.short_title),
                    notice: 'Ticket successfully destroyed.'
      else
        redirect_to admin_conference_tickets_path(conference_id: @conference.short_title),
                    error: 'Ticket was successfully destroyed.' \
                    "#{@ticket.errors.full_messages.join('. ')}."
      end
    end

    private

    def update_purchased_ticket_purchases(user)
      user.ticket_purchases.by_conference(@conference).unpaid.each do |ticket_purchase|
        ticket_purchase.pay(@payment)
      end
    end

    def payment_params
      params.require(:payment).permit(:last4, :authorization_code)
    end
  end
end
