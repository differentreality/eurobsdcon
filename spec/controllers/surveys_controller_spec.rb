# frozen_string_literal: true

require 'spec_helper'

describe SurveysController do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }

  let!(:conference) { create(:conference, start_date: Date.current - 1.day, end_date: Date.current + 1.day, timezone: Time.current.zone) }
  let!(:survey_future) { create(:survey, surveyable: conference, start_date: Date.current + 2.days, end_date: Date.current + 3.days) }
  let!(:survey_past) { create(:survey, surveyable: conference, start_date: Date.current - 1.day, end_date: Date.current - 1.day) }
  let!(:survey_present) { create(:survey, surveyable: conference, start_date: Date.current - 1.day, end_date: Date.current + 1.day, target: 'during_registration') }
  let(:boolean_question){ create(:survey_question, survey: survey_present) }

  describe 'GET #index' do
    context 'guest' do
      before :each do
        get :index, conference_id: conference.short_title
      end

      it '@sureveys variable is nil' do
        expect(assigns(:surveys)).to eq [survey_present]
      end
    end

    context 'signed in user' do
      before :each do
        sign_in user
        get :index, conference_id: conference.short_title
      end

      it 'assigns @surveys with active surveys' do
        expect(assigns(:surveys)).to eq [survey_present]
      end
    end
  end

  describe '#reply' do
    before :each do
      sign_in user
    end

    it 'redirects to registration page' do
      post :reply, survey_submission: { boolean_question.id => ['', 'Yes'] }, id: survey_present.id, conference_id: conference.short_title

      expect(response).to redirect_to conference_conference_registration_path
    end

    it 'redirect to root_path' do
      survey_present.target = 'after_conference'
      survey_present.save!
      survey_present.reload
      post :reply, survey_submission: { boolean_question.id => ['', 'Yes'] }, id: survey_present.id, conference_id: conference.short_title

      expect(response).to redirect_to root_path
    end
  end
end
