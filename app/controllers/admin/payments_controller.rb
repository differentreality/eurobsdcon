module Admin
  class PaymentsController < Admin::BaseController
    load_resource :conference, find_by: :short_title
    load_resource :user
    load_and_authorize_resource

    def index
      @payments = Payment.where(conference: @conference).order(created_at: :desc)
      @registered_users = User.where(id: @conference.registrations.pluck(:user_id))
    end

    def new
      @ticket_purchase = @conference.ticket_purchases.new
      @user_registration = @user.registrations.for_conference @conference
      @overall_discount_percent = @user.overall_discount_percent(@conference)
      @overall_discount_value = @user.overall_discount_value(@conference)
    end

    private

    def payment_params
      params.require(:payment).permit(:amount, :user_id, :last4, :authorization_code)
    end
  end
end
