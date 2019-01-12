FactoryBot.define do
  factory :invoice do
    no 1
    date Date.current - 1
    payable 1000
    conference

  end
end
