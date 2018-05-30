FactoryGirl.define do
  factory :coupon do
    name { Faker::Hipster.sentence }
    discount_type 0
    discount_amount 100

    conference
  end
end
