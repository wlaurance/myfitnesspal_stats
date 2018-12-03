require 'spec_helper'
require 'date'

context Scraper, :vcr do 
  before(:each) do
    username = ENV["MFP_USERNAME"] || "rspec_test"
    password = ENV["MFP_PASSWORD"] || "123456"

    @scraper = Scraper.new username, password
    @scraper.login
  end

  it 'can get data for a specified day' do
    data = @scraper.get_by_date Date.parse("1-12-2018")
    puts data
  end
end