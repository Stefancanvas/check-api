require 'chromeshot'

unless Rails.env.test?
  puts "Starting Chromeshot on port #{CONFIG['chrome_debug_port']}"
  Chromeshot::Screenshot.setup_chromeshot(CONFIG['chrome_debug_port'])
end
