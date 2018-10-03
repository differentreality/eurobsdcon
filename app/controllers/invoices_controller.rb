class InvoicesController < ApplicationController
  load_resource :conference, find_by: :short_title
  load_and_authorize_resource :user
  load_and_authorize_resource through: :user, except: :request_invoice
  load_resource :payment

  # GET /invoices
  # GET /invoices.json
  def index
    @invoices = current_user.invoices.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @invoices }
    end
  end

  # GET /invoices/1
  # GET /invoices/1.json
  def show
    respond_to do |format|
      format.html
      format.pdf do
        html = render_to_string(action: 'show.html.haml', layout: 'invoice_pdf')
        kit = PDFKit.new(html)
        filename = "invoice_#{@invoice.number}_#{@invoice.conference.short_title}.pdf"

        send_data kit.to_pdf, filename: filename, type: 'application/pdf'
        return
      end
      format.json { render json: @invoice }
    end
  end

  def request_invoice
    current_user.update_attributes(user_params) if params[:user]

    begin
      raise 'No invoice details' unless current_user.invoice_details
      RequestInvoiceMailJob.perform_later(current_user, @conference, @payment)
      redirect_back fallback_location: conference_conference_registration_path(@conference.short_title), notice: 'Invoice requested'
    rescue => e
      redirect_to :back, error: "An error occured while requesting your invoice. #{e.message}"
    end
  end

  private

   def user_params
     params.require(:user).permit(:invoice_details, :invoice_vat)
   end
end
