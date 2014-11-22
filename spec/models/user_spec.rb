require 'spec_helper'

describe User do
  describe '::find_or_create_using_google_oauth2' do
    it 'calls #find_or_create with name and email' do
      expect(User).to receive(:find_or_create).with 'a', 'a@a.it'
      auth_data = { 'info' => { 'name' => 'a', 'email' => 'a@a.it' } }
      User.find_or_create_using_google_oauth2 auth_data
    end

    it 'returns #find_or_create return value' do
      allow(User).to receive(:find_or_create).and_return 'asd'
      auth_data = { 'info' => { 'name' => 'a', 'email' => 'a@a.it' } }
      expect(User.find_or_create_using_google_oauth2 auth_data).to eq 'asd'
    end
  end

  describe '::find_or_create' do
    context 'when a user with the given email does not exist' do
      before do
        allow(User).to receive(:find_by_email).with('a@a.it').and_return nil
      end

      it 'creates a user' do
        expect(User).to receive(:create).with('a', 'a@a.it')
        User.find_or_create('a', 'a@a.it')
      end

      it 'returns the creation result' do
        allow(User).to receive(:create).and_return 'asd'
        expect(User.find_or_create 'a', 'a@a.it').to eq 'asd'
      end
    end

    context 'when a user with the given email exists' do
      before do
        allow(User).to receive(:find_by_email).with('a@a.it').and_return 'asd'
      end

      it 'returns the find result' do
        expect(User.find_or_create 'a', 'a@a.it').to eq 'asd'
      end
    end
  end

  describe '::find_by_email' do
    context 'when the given email is paired to an id' do
      before do
        $r.set "email.to.id:a@a.it", "2"
      end

      it 'finds the user' do
        expect(User).to receive(:find).with "2"
        User.find_by_email "a@a.it"
      end

      it 'returns the find result' do
        allow(User).to receive(:find).and_return "asd"
        expect(User.find_by_email "a@a.it").to eq "asd"
      end
    end

    context 'when the given email is not paired to an id' do
      it 'returns nil' do
        expect(User.find_by_email 'a@a.it').to be_nil
      end
    end
  end

  describe '#find' do
    context 'when the given id exist' do
      before do
        $r.hmset "user:1", "email", "a@a.it"
      end

      it "creates a new user object" do
        expect(User.find 1).to be_a User
      end

      it "pass the found attributes to the user constructor" do
        expect(User).to receive(:new).with("email" => "a@a.it")
        User.find 1
      end
    end

    context 'when the given id does not exist' do
      it "returns nil" do
        expect(User.find 1).to be_nil
      end
    end
  end

  describe '::create' do
    it "sets an association between email and id" do
      User.create "a", "a@a.it"
      expect($r.get "email.to.id:a@a.it").to eq "1"
    end

    it "generates an auth token" do
      allow(User).to receive(:generate_auth_token).and_return "foobar"
      User.create "a", "a@a.it"
      expect($r.get "auth:foobar").to eq "1"
    end

    it "sets all user attributes" do
      allow(User).to receive(:generate_auth_token).and_return "foobar"
      allow(User).to receive(:generate_api_secret).and_return "barbaz"
      Timecop.freeze do
        User.create "a", "a@a.it"
        expect($r.hgetall "user:1").to eq({
          "id" => "1",
          "name" => "a",
          "ctime" => Time.now.to_i.to_s,
          "karma" => UserInitialKarma.to_s,
          "about" => "",
          "email" => "a@a.it",
          "auth" => "foobar",
          "apisecret" => "barbaz",
          "flags" => "",
          "karma_incr_time" => Time.now.to_i.to_s
        })
      end
    end
  end
end
