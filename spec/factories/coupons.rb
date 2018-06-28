FactoryGirl.define do
  factory :coupon do
    name { Faker::Hipster.sentence }
    discount_amount 10
    conference

    factory :coupon_value do
      discount_type 1
    end

    factory :coupon_percent do
      discount_type 0
    end
  end
end
