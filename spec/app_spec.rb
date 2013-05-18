require 'app'
require 'rspec'

set :environment, :test

describe 'urls_to_links' do
  [
    { :input => 'http://example.com',  :href => 'http://example.com',     :text => 'http://example.com' },
    { :input => 'http://example.com.', :href => 'http://example.com',     :text => 'http://example.com' },
    { :input => 'https://example.com', :href => 'https://example.com',    :text => 'https://example.com' },
    { :input => 'www.example.com',     :href => 'http://www.example.com', :text => 'www.example.com' },
    { :input => 'www.example.com.',    :href => 'http://www.example.com', :text => 'www.example.com' }
  ].each do |test_case|
    it "converts '#{test_case[:input]}' to HTML link to #{test_case[:href]}" do
      expected_link = "<a rel=\"nofollow\" href=\"#{test_case[:href]}\">#{test_case[:text]}</a>"
      urls_to_links(test_case[:input]).should match(expected_link)
    end
  end
end