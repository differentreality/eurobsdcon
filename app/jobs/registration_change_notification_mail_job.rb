class RegistrationChangeNotificationMailJob < ApplicationJob
  queue_as :default

  def perform(conference, registration_user, action)

    User.registration_notifiable(conference).each do |recipient|
      Mailbot.registration_change_notification_mail(conference, registration_user, action, recipient).deliver_now
    end
  end
end
