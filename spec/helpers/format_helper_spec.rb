# frozen_string_literal: true

require 'spec_helper'

describe FormatHelper, type: :helper do

  describe 'discount' do
    it 'returns correct text for discount' do
      coupon = create(:coupon_full_discount)
      expect(discount(coupon)).to eq '100%'
    end
  end

  describe 'markdown' do
    it 'should return empty string for nil' do
      expect(markdown(nil)).to eq ''
    end

    it 'should return HTML for header markdown' do
      expect(Redcarpet::Markdown).to receive(:new)
      .with(Redcarpet::Render::HTML, autolink: true, space_after_headers: true, no_intra_emphasis: true)
      .and_call_original

      expect(markdown('# this is my header')).to eq "<h1>this is my header</h1>\n"
    end
  end
end
