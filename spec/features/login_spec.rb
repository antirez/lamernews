require 'spec_helper'
disable :run

require 'capybara'
require 'capybara/dsl'
Capybara.app = Sinatra::Application
Capybara.default_driver = :selenium

RSpec.configure do |config|
  config.include Capybara::DSL
end

describe 'login feature', js: true do
  it 'a new user can create an account' do
    visit '/'
    click_on 'login / register'
    fill_in 'username', with: 'foobar'
    fill_in 'password', with: 'bazbarbaz'
    check 'register'
    click_on 'Login'
    expect(page).to have_content 'foobar'
  end
end
