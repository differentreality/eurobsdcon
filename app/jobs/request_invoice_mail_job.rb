# frozen_string_literal: true

class RequestInvoiceMailJob < ApplicationJob
  queue_as :default

  def perform(user, conference, payment=nil)
    Mailbot.invoice_request(user, conference, payment).deliver_later
  end
end
