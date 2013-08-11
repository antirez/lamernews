require_relative '../app'
require 'rspec'
require 'rack/test'

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

describe 'Lamer News' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  describe '/api/create_account' do
    ['anti rez', '0antirez', '_antirez'].each do |invalid_username|
      context "with #{invalid_username} as username" do
        before do
          post '/api/create_account', {'username' => invalid_username, 'password' => 'valid password'}
        end

        it 'returns "Username must match" error' do
          last_response.should be_ok
          JSON.parse(last_response.body)['status'].should eq('err')
          JSON.parse(last_response.body)['error'].should match(/Username must match/)
        end
      end
    end

    ['antirez', 'Antirez', 'antirez0', 'anti_rez', 'anti-rez'].each do |valid_username|
      context "with #{valid_username} as username" do
        before do
          post '/api/create_account', {'username' => valid_username, 'password' => 'valid password'}
        end

        it 'doesn\'t return "Username must match" error' do
          last_response.should be_ok
          JSON.parse(last_response.body)['error'].should_not match(/Username must match/)
        end
      end
    end
  end
end