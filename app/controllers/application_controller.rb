# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :set_paper_trail_whodunnit
  include ApplicationHelper
  add_flash_types :error
  protect_from_forgery with: :exception, prepend: true
  before_action :store_location
  # Ensure every controller authorizes resource or skips authorization (skip_authorization_check)
  check_authorization unless: :devise_controller?
  skip_authorization_check only: [:invoice_info, :euro_to_nok]

  def store_location
    # store last url - this is needed for post-login redirect to whatever the user last visited.
    return unless request.get?

    if (request.path != '/accounts/sign_in' &&
        request.path != '/accounts/sign_up' &&
        request.path != '/accounts/password/new' &&
        request.path != '/accounts/password/edit' &&
        request.path != '/accounts/confirmation' &&
        request.path != '/accounts/sign_out' &&
        request.path != '/users/ichain_registration/ichain_sign_up' &&
        !request.path.starts_with?(Devise.ichain_base_url) &&
        !request.xhr?) # don't store ajax calls
      session[:return_to] = request.fullpath
    end
  end

  def after_sign_in_path_for(_resource)
    if (can? :view, Conference) &&
      (!session[:return_to] ||
      session[:return_to] &&
      session[:return_to] == root_path)
      admin_conferences_path
    else
      session[:return_to] || root_path
    end
  end

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  rescue_from CanCan::AccessDenied do |exception|
    Rails.logger.debug "Access denied on #{exception.action} #{exception.subject.inspect}"
    message = exception.message
    message << ' Maybe you need to sign in?' unless @ignore_not_signed_in_user || current_user
    redirect_to root_path, alert: message
  end

  rescue_from IChainRecordNotFound do
    Rails.logger.debug('IChain Record was not Unique!')
    sign_out(current_user)
    redirect_to root_path,
                error: 'Your E-Mail adress is already registered at OSEM. Please contact the admin if you want to attach your openSUSE Account to OSEM!'
  end

  rescue_from UserDisabled do
    Rails.logger.debug('User is disabled!')
    sign_out(current_user)
    mail = User.admin.first ? User.admin.first.email : 'the admin!'
    redirect_to User.ichain_logout_url, error:  "This User is disabled. Please contact #{mail}!"
  end

  def invoice_info
    model = params[:model]
    id = params[:id]

    recipient = model.camelize.constantize.find_by(id: id.to_i)
    @vat = recipient.invoice_vat
    @details = recipient.invoice_details
    @tickets_grouped = []
    @tickets_collection = []

    if recipient.class.to_s == 'User'
      conference = Conference.find_by(short_title: params[:conference_id]) if params[:conference_id]
      ticket_purchases = recipient.ticket_purchases.where(conference: conference).where.not(ticket: nil)
      @tickets_grouped = tickets_grouped(ticket_purchases)
      @tickets_collection = tickets_collection(@tickets_grouped)
    end

    render 'shared/invoice_info'
  end

  def euro_to_nok
    vat_value = params['vat_value']
    result = ApplicationController.helpers.euro_to_nok(vat_value)

    respond_to do |format|
      format.js { render text: result }
    end
  end

  def not_found
    raise ActionController::RoutingError.new('Not Found')
  end

  private

  ##
  # Result:
  # [ { ticket: ticket, price: 0, quantity: 1, ticket_purchase_ids: [1,2] }, { } ]
  # ==== Gets
  # * +ActiveRecord Collection+ -> ticket purchases
  # ==== Returns
  # * +Array+ * -> With ticket information
  def tickets_grouped(ticket_purchases)
    ticket_purchases.group_by(&:ticket).map{ |ticket, purchases|
      [ticket, purchases.group_by(&:final_amount)
      .map{ |amount, p| [amount, p.pluck(:quantity).sum, p.pluck(:id)] }  ]}
      .to_h.map{ |ticket, p| p.map{ |x| { :ticket => ticket,
                                          :price => x.first,
                                          :quantity => x.second,
                                          :vat_percent => ticket&.ticket_group&.vat_percent,
                                          :ticket_purchase_ids => x.last} } }.flatten
  end

  def tickets_selected(tickets_grouped)
    result = tickets_grouped.select{ |data| @invoice.description.any?{ |invoice_item| invoice_item[:description] == data[:ticket].title &&
                                                                                      invoice_item[:quantity] == data[:quantity].to_s && invoice_item[:price] == data[:price].to_s} }
    return result
  end

  ##
  # Create collection for select input of tickets, grouped by price
  # ==== Returns
  # [
  #   ['ticket title (quantity * price)', [ticket purchase ids],
  #     { :id, data: { :ticket_name, :quantity, :price, :index } }
  #   ]
  # ]
  # Example:
  # [ ['ticket title (1 * 10.0 EUR)', [1,2,3], { id: 'tickets_collection_option1',
  #                                              data: { ticket_name: 'tickeet title',
  #                                                      quantity: 1,
  #                                                      price: 10.0,
  #                                                      index: 1 } } ],
  #   ['other ticket'] ]
  def tickets_collection(tickets_grouped)
    tickets_grouped.map.with_index(1){ |data, index|
      ["#{data[:ticket].title} (#{data[:quantity]} * #{data[:price]} #{data[:ticket].price_currency})",
        data[:ticket_purchase_ids].split.join(', '),
        id: "tickets_collection_option#{index}",
        data: { ticket_name: data[:ticket].title,
                quantity: data[:quantity],
                price: data[:price],
                vat_percent: data[:ticket].ticket_group&.vat_percent || 0,
                index: index }
      ] }
  end
end
