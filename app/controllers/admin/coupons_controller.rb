module Admin
  class CouponsController < Admin::BaseController
    load_and_authorize_resource :conference, find_by: :short_title
    load_and_authorize_resource through: :conference

    # GET /coupons
    # GET /coupons.json
    def index
      @coupons = Coupon.all
      # data for pie chart
      @data = @coupons.map{ |coupon| { coupon.name => coupon.registrations.count } }
      @data = Hash[*@data.collect{|h| h.to_a}.flatten]

      respond_to do |format|
        format.html # index.html.erb
        format.json { render json: @coupons }
      end
    end

    # GET /coupons/1
    # GET /coupons/1.json
    def show
      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @coupon }
      end
    end

    # GET /coupons/new
    def new
      @coupon = @conference.coupons.new
      @tickets = @conference.tickets
      @currencies = @tickets.map{ |ticket| { 'id' => ticket.id, 'currency' => ticket.price_currency } }.to_json.html_safe
    end

    # GET /coupons/1/edit
    def edit
    end

    # POST /coupons
    # POST /coupons.json
    def create
      @coupon = @conference.coupons.new(coupon_params)

      respond_to do |format|
        if @coupon.save
          format.html { redirect_to admin_conference_coupons_path(@conference), notice: 'Coupon was successfully created.' }
          format.json { render json: @coupon, status: :created }
        else
          @tickets = @conference.tickets
          @currencies = @tickets.map{ |ticket| { 'id' => ticket.id, 'currency' => ticket.price_currency } }.to_json.html_safe
          format.html { render action: 'new' }
          format.json { render json: @coupon.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /coupons/1
    # PATCH/PUT /coupons/1.json
    def update
      respond_to do |format|
        if @coupon.update(coupon_params)
          format.html { redirect_to @coupon, notice: 'Coupon was successfully updated.' }
          format.json { head :no_content }
        else
          format.html { render action: 'edit' }
          format.json { render json: @coupon.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /coupons/1
    # DELETE /coupons/1.json
    def destroy
      @coupon.destroy
      respond_to do |format|
        format.html { redirect_to admin_conference_coupons_path(@conference) }
        format.json { head :no_content }
      end
    end

    def set_ticket
      @ticket = @conference.tickets.find_by(id: params[:id])
    end

    private

      # Never trust parameters from the scary internet, only allow the white list through.
      def coupon_params
        params.require(:coupon).permit(:ticket_id,
                                       :discount_type,
                                       :discount_amount,
                                       :name,
                                       :description)
      end
  end
end
