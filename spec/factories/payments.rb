# frozen_string_literal: true

FactoryBot.define do
  factory :payment do
    user
    conference
    status { 'unpaid' }
    last4 '0000'

    factory :payment_paid do
      status { 'success' }
    end

    factory :payment_failed do
      status { 'failed' }
    end
  end
end
