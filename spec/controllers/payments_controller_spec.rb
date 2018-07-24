# frozen_string_literal: true

require 'spec_helper'

describe PaymentsController do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }

  let!(:conference) { create(:conference, start_date: Date.current - 1.day, end_date: Date.current + 1.day, timezone: Time.current.zone) }
  let!(:survey_future) { create(:survey, surveyable: conference, start_date: Date.current + 2.days, end_date: Date.current + 3.days, target: 'during_registration') }
  let!(:survey_past) { create(:survey, surveyable: conference, start_date: Date.current - 1.day, end_date: Date.current - 1.day, target: 'after_conference') }
  let!(:survey_present) { create(:survey, surveyable: conference, start_date: Date.current - 1.day, end_date: Date.current + 1.day, target: 'during_registration') }

  let(:conference_without_survey) { create(:conference) }

  describe '#create' do
    before :each do
      sign_in user
      stub_request(:post, "https://api.paymill.com/v2.1/transactions/").
         with(body: {"amount"=>"10000", "currency"=>"USD", "description"=>"DiVbMQ -  Registration ID "},
              headers: {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Authorization'=>'Basic ZjU0MmE1YTBjODg4NDdhNjYyYTc4ZTdhOGQ3ZTRhZDU6', 'Content-Type'=>'application/x-www-form-urlencoded', 'User-Agent'=>'Ruby'})
    end
    context 'without survey' do
      before :each do
        post :create, payment: { amount: 10000 }, conference_id: conference_without_survey
      end

      it 'redirects to registration page' do
        expect(response).to redirect_to conference_conference_registration_path
      end
    end
  end
end
