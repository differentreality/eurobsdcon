# frozen_string_literal: true

class SurveysController < ApplicationController
  before_action :authenticate_user!, except: [:index]
  load_resource :conference, find_by: :short_title
  load_and_authorize_resource except: :reply
  load_resource only: :reply
  skip_authorization_check only: :reply

  def index
    @surveys = @conference.surveys.select(&:active?)
    @surveys = @surveys - @conference.surveys.after_conference unless @conference.ended?
  end

  def show
    @survey_submission = @survey.survey_submissions.new
    @request_referer = request.referer
  end

  def reply
    redirect_link = case @survey.target
                    when 'during_registration'
                      conference_conference_registration_path(@conference)
                    when 'after_conference'
                      root_path
                    end

    unless can? :reply, @survey
      redirect_to conference_survey_path(@conference, @survey), alert: 'This survey is currently closed'
      return
    end

    replyable = params[:replyable_type]&.camelize&.constantize&.find_by(id: params[:replyable_id])

    @survey.survey_questions.each do |survey_question|
      reply = survey_question.survey_replies.find_by(user: current_user, replyable: replyable)
      reply_text = params[:survey_submission][survey_question.id.to_s]&.reject(&:blank?)&.join(',')

      if reply
        reply.update_attributes(text: reply_text) unless reply.text == reply_text
      else
        survey_question.survey_replies.create!(text: reply_text, user: current_user, replyable: replyable)
      end

      user_survey_submission = @survey.survey_submissions.find_by(user: current_user)
      if user_survey_submission
        user_survey_submission.update_attributes(updated_at: Time.current)
      else
        @survey.survey_submissions.create!(user: current_user)
      end
    end

    redirect_to redirect_link || root_path
  end
end

private

def survey_params
  params.require(:survey_submission).permit(:replyable_id, :replyable_type)
end
