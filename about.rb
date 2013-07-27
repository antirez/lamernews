get '/about' do
    @title = "About - #{SiteName}"
    erb :about
end
