FactoryBot.define do
  factory :invoice_item do
    description { Faker::Hipster.sentence }
    quantity 1
    price 350
    invoice
    conference
  end
end
