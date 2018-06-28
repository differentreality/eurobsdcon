# frozen_string_literal: true

module TicketHelper
  def price_with_discount(ticket, registration, symbol=false)
    ticket_discount = Money.new(ticket.discount(registration)*100, ticket.price_currency)
    result = ticket.price - ticket_discount

    if symbol
      return humanized_money_with_symbol result
    else
      return humanized_money result
    end
  end

  def overall_discount_text(conference)
    text_array = []
    text_percent = ''
    if current_user.overall_discount_percent(conference) > 0
      text_percent += current_user.overall_discount_percent(conference).to_f.to_s
      text_percent += '%'
      text_percent += "\n"
      text_array[0] = text_percent
    end

    if current_user.overall_discount_value(conference) > 0
      value = Money.new(current_user.overall_discount_value(conference) * 100, conference.tickets.first.price_currency)
      text_array[1] = humanized_money_with_symbol(value)
    end

    return text_array.join("\n")
  end
end
