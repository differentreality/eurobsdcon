# frozen_string_literal: true

module Admin
  module InvoicesHelper
    def euro_to_nok(euro_value, rate=nil)
      euro_value = euro_value.to_f
      return 0 unless euro_value > 0

      unless rate
        nok_rate_results = `./euro-nok-conversion.perl`
        rate = nok_rate_results.lines.last&.split(',').last.to_f if nok_rate_results
      end

      return 0 unless rate

      nok_value = euro_value * rate
      return number_with_precision(nok_value, precision: 2)
    end
  end
end
