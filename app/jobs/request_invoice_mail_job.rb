# frozen_string_literal: true

class RequestInvoiceMailJob < ApplicationJob
  queue_as :default

  def perform(user, conference)
    Mailbot.invoice_request(user, conference).deliver_later
  end
end
