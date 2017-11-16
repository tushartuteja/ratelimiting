class HomeController < ApplicationController
  add_limit 1.hour, 100 , controller: 'home' ,   action: 'index'

  def index
    render text: "ok" , status: 200
  end
end
