# config/initializers/pdfkit.rb
PDFKit.configure do |config|
  config.wkhtmltopdf = '/usr/bin/wkhtmltopdf'

  config.default_options = {
    # print_media_type: true,
    load_error_handling: 'ignore',
    load_media_error_handling: 'ignore',
    page_size: 'A4',
    margin_top: '1in',
    margin_right: '0.2in',
    margin_left: '0.2in',
    margin_bottom: '1in',
    minimum_font_size: 10
  }
  # Use only if your external hostname is unavailable on the server.
#   config.root_url = "http://localhost:3000"
#   config.root_url = "http://localhost"
#   config.verbose = false
end
