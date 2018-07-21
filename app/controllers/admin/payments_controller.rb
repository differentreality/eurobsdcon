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
      @user_registration = @user.registrations.for_conference @conference
      @overall_discount_percent = @user.overall_discount_percent(@conference)
      @overall_discount_value = @user.overall_discount_value(@conference)
    end

    def show
      @ticket_purchases = @payment.ticket_purchases.group_by(&:ticket).map{|ticket, purchases| [ticket, purchases.group_by(&:amount_paid).map{|amount, p| [amount, p.pluck(:quantity).sum, p.pluck(:id)] }  ]}.to_h.map{|ticket, p| p.map{|x| { :ticket => ticket, :price => x.first, :quantity => x.second, :ticket_purchase_ids => x.last} } }.flatten
    end

    private

    def payment_params
      params.require(:payment).permit(:amount, :user_id, :last4, :authorization_code)
    end
  end
end
