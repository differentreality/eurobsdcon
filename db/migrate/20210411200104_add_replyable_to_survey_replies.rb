class AddReplyableToSurveyReplies < ActiveRecord::Migration[5.2]
  def change
    add_reference :survey_replies, :replyable, polymorphic: true, index: true
  end
end
