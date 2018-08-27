module Admin
  class PaymentsController < Admin::BaseController
    load_and_authorize_resource
    load_resource :conference, find_by: :short_title
    load_resource :user

    def index
      @payments = @conference.payments.order(created_at: :desc)
      @registered_users = User.where(id: @conference.registrations.pluck(:user_id))
    end

    def new
      @ticket_purchase = @conference.ticket_purchases.new
      @payment = @conference.payments.new(user: @user)
      @url = admin_conference_ticket_purchases_path(@conference)
      @user_registration = @user.registrations.for_conference @conference
      @overall_discount_percent = @user.overall_discount_percent(@conference)
      @overall_discount_value = @user.overall_discount_value(@conference)
    end

    def show
      @ticket_purchases = @payment.ticket_purchases.group_by(&:ticket).map{|ticket, purchases| [ticket, purchases.group_by(&:amount_paid).map{|amount, p| [amount, p.pluck(:quantity).sum, p.pluck(:id)] }  ]}.to_h.map{|ticket, p| p.map{|x| { :ticket => ticket, :price => x.first, :quantity => x.second, :ticket_purchase_ids => x.last} } }.flatten
    end

    def edit
      @user = @payment.user
      @url = admin_conference_payment_path(@conference, @payment)
      @selection = @payment.ticket_purchases.map{ |tp| [tp.ticket_id, tp.quantity] }.compact.to_h
    end

    def update
      amount = params[:payment][:amount].to_f * 100.0
      if @payment.update_attributes(payment_params)
        @payment.update_attribute(:amount, amount)
        # if we mark as paid
        # mark all ticket purchases of this payment, also as paid
        if params[:payment][:status] == 'success'
          @payment.ticket_purchases.each do |ticket_purchase|
            ticket_purchase.pay(@payment)
          end
        end

        if @payment.unpaid? || @payment.failure?
          # Destroy physical tickets
          # Mark ticket purchases as unpaid and destroy physical_tickets
          @payment.ticket_purchases.each do |ticket_purchase|
            ticket_purchase.unpay(@payment)
          end
        end
        flash[:notice] = 'Payment updated successfuly'
        redirect_to admin_conference_payments_path
      else
        flash[:error] = 'Could not update payment. ' + @payment.errors.full_messages.to_sentence
        render :edit
      end
    private

    def payment_params
      params.require(:payment).permit(:amount, :user_id, :last4, :authorization_code, :status)
    end
  end
end
