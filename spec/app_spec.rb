require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "LamerNews App" do
  describe "news" do
    it "respond to /" do
      get '/'
      last_response.should be_ok, last_response.body
    end

    it "return 404 when page cannot be found" do
      get '/404'
      last_response.status.should == 404
    end

    it "return the correct content-type when viewing RSS" do
      get '/rss'
      last_response.headers["Content-Type"].should == "text/xml;charset=utf-8"
    end
  end

  describe "users" do
    it "protect submit page" do
      get '/submit'
      follow_redirect!
      last_request.url.should == "http://example.org/login"
      last_response.should be_ok, last_response.body
    end
  end
end
