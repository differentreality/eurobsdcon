module Admin
  class InvoicesController < Admin::BaseController
    load_and_authorize_resource
    load_and_authorize_resource :conference, find_by: :short_title
    load_resource :physical_ticket
    load_resource :payment
    load_resource :sponsor, only: :new
    load_resource :user, only: :new

    # GET /invoices
    # GET /invoices.json
    def index
      payment_invoices = @payment&.ticket_purchases&.collect{ |tp| tp.invoices }&.compact&.first
      @invoices = payment_invoices || @conference.invoices

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

    # GET /invoices/new
    def new
      @url = admin_conference_invoices_path(@conference.short_title)
      kind = 0
      @user ||= @payment.try(:user)
      total_amount = 0
      paid = @payment && @payment.success? ? true : false
      total_amount = @payment.amount / 100.0 if @payment

      if params[:kind] == 'sponsorship'
        recipient = Sponsor.find(params[:recipient_id])
        description = [{ description: "Sponsorship #{@conference.title}", quantity: 1 }]
        total_amount = 0
      else # params[:kind] == 'ticket_purchases'
        kind = 1
        ticket_purchases = if @payment
                             @payment&.ticket_purchases
                           elsif @user
                             @user&.ticket_purchases&.where(conference: @conference)&.where&.not(ticket: nil)
                           else
                             []
                           end

        @tickets_grouped = tickets_grouped(ticket_purchases)
        @tickets_collection = tickets_collection(@tickets_grouped)
        @tickets_selected = @tickets_grouped

        total_amount = total_amount || @tickets_grouped.sum{ |p| p[:price] * p[:quantity] }.to_f
      end

      recipient = if params[:recipient_type]
                    params[:recipient_type].camelize.constantize.find(params[:recipient_id])
                  else
                    @user
                  end

      recipient_details = recipient&.invoice_details
      recipient_vat = recipient&.invoice_vat


      vat_percent = 0 #ENV['VAT_PERCENT'].to_f
      vat = total_amount * vat_percent / 100
      payable =  '%.2f' % ((total_amount + vat).to_f)

      no = (Invoice.order(no: :asc).last.try(:no) || 0) + 1

      @invoice = @conference.invoices.new(no: no, date: Date.current,
                                          kind: kind, paid: paid,
                                          total_amount: total_amount,
                                          vat_percent: vat_percent,
                                          vat: vat,
                                          payable: payable,
                                          description: description,
                                          recipient: recipient,
                                          recipient_details: recipient_details,
                                          recipient_vat: recipient_vat)

      # .map(&:ticket).map{ |purchase| ["#{purchase.ticket.title} (#{purchase.quantity})", purchase.id] }
      # @ticket_purchases_collection = @conference.ticket_purchases.where(user: @physical_ticket.user).group_by(&:ticket).map{ |ticket, purchases| [ticket, quantity: purchases.sum(&:quantity), total_price: purchases.sum(&:amount_paid)] }.map{|ticket, data| [ticket.title, ticket.id, data: { ticket_name: ticket.title, quantity: data[:quantity], total_price: data[:total_price]} ]}
    end

    # GET /invoices/1/edit
    def edit
      @url = admin_conference_invoice_path(@conference.short_title, @invoice)

      ticket_purchases = if @invoice.recipient && @invoice.recipient_type == 'User'
                           @invoice.recipient.ticket_purchases.where(conference: @conference).where.not(ticket: nil)
                         else
                           []
                         end

      @tickets_grouped = tickets_grouped(ticket_purchases)
      @tickets_collection = tickets_collection(@tickets_grouped)
      @tickets_selected = tickets_selected(@tickets_grouped)
    end

    # POST /invoices
    # POST /invoices.json
    def create
      @invoice = @conference.invoices.new(invoice_params)
      @payment = Payment.find(params[:payment_id]) if params[:payment_id].present?
      @user = @payment.try(:user)

      if params[:invoice][:ticket_purchase_ids].present?
        ticket_purchase_ids = params[:invoice][:ticket_purchase_ids].split.first.map(&:to_i)
        ticket_purchases = TicketPurchase.where(id: ticket_purchase_ids)

        @invoice.ticket_purchase_ids = ticket_purchases.pluck(:id)
      end

      # Only 1 recipient is selected
      # @invoice.recipient_id = invoice_params[:recipient_id]&.join&.to_i
      # @invoice.recipient_type = 'User'

      respond_to do |format|
        if @invoice.save
          format.html { redirect_to admin_conference_invoice_path(@conference.short_title, @invoice), notice: 'Invoice was successfully created.' }
          format.json { render json: @invoice, status: :created }
        else
          ticket_purchases = @invoice.recipient&.ticket_purchases&.where(conference: @conference)&.where&.not(ticket: nil) || []
          @tickets_grouped = tickets_grouped(ticket_purchases)
          @tickets_collection = tickets_collection(@tickets_grouped)
          @tickets_selected = tickets_selected(@tickets_grouped)

          @url = admin_conference_invoices_path(@conference.short_title)

          format.html { render action: 'new' }
          format.json { render json: @invoice.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /invoices/1
    # PATCH/PUT /invoices/1.json
    def update
      respond_to do |format|
        if @invoice.update_attributes(invoice_params)
          format.html { redirect_to admin_conference_invoice_path(@conference.short_title, @invoice), notice: 'Invoice was successfully updated.' }
          format.json { head :no_content }
        else
          ticket_purchases = @invoice.recipient&.ticket_purchases&.where(conference: @conference)&.where&.not(ticket: nil) || []
          @tickets_grouped = tickets_grouped(ticket_purchases)
          @tickets_collection = tickets_collection(@tickets_grouped)
          @tickets_selected = tickets_selected(@tickets_grouped)

          format.html {
            flash[:error] = 'Could not update invoice. ' + @invoice.errors.full_messages.to_sentence
            @url = admin_conference_invoice_path(@conference.short_title, @invoice)
            render action: 'edit' }
          format.json { render json: @invoice.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /invoices/1
    # DELETE /invoices/1.json
    def destroy
      @invoice.destroy
      respond_to do |format|
        format.html { redirect_to admin_conference_invoices_path(@conference) }
        format.json { head :no_content }
      end
    end

    def add_item
      respond_to do |format|
        format.js
      end
    end

    private

      # Never trust parameters from the scary internet, only allow the white list through.
      def invoice_params
        params.require(:invoice).permit(:no, :date, :conference_id, :currency,
                                        :recipient_details, :recipient_vat,
                                        :recipient_type,
                                        :quantity, :total_quantity,
                                        :item_price, :total_price,
                                        :total_amount, :vat_percent, :vat,
                                        :payable, :paid, :kind,
                                        :payment_id, :recipient_id, ticket_purchase_ids: [],
                                        description: [:description, :quantity, :price] )
      end
  end
end
