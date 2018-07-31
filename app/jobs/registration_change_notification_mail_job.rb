class RegistrationChangeNotificationMailJob < ApplicationJob
  queue_as :default

  def perform(conference, registration_user, action, coupon=nil)

    User.registration_notifiable(conference).each do |recipient|
      Mailbot.registration_change_notification_mail(conference, registration_user, action, recipient, coupon).deliver_now
    end
  end
end
