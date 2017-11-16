require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do

  controller do
    include Limiting
    add_limit 2.seconds, 10
    add_limit 5.seconds, 15  , controller: 'anonymous'
    add_limit 10.seconds, 18  , controller: 'anonymous' , action: 'index'

    def index
      render text: "ok" , status: 200
    end
    
  end

  describe "checking limiting module" do

    before(:each) do
      redis = Redis.current
      keys = redis.keys("limiting_module_*")
      keys.each do |key|
        redis.del key
      end
    end
    it "returns ok when in limits and 429 when not in limits" do
      10.times do
        get :index
        expect(response.body).to eq("ok")
      end

      get :index
      expect(response.body).to match("Rate limit exceeded")
      expect(response.status).to eq(429)

      sleep(3)

      5.times do
        get :index
        expect(response.body).to eq("ok")
      end


      get :index
      expect(response.body).to match("Rate limit exceeded")
      expect(response.status).to eq(429)

      sleep(6)

      3.times do
        get :index
        expect(response.body).to eq("ok")
      end


      get :index
      expect(response.body).to match("Rate limit exceeded")
      expect(response.status).to eq(429)



    end


  end


end
