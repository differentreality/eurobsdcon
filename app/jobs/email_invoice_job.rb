# frozen_string_literal: true

class EmailInvoiceJob < ApplicationJob
  queue_as :default

  def perform(user, conference)
    Mailbot.email_invoice(user, conference).deliver_later
  end
end
