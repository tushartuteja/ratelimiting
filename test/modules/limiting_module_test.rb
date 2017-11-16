require 'test_helper'

class LimitingModuleTest < ActiveSupport::TestCase
  module TestingModule
    def before_action action
      @action = action
    end


  end

  def setup
    @dummy_controller = Object.new
  end

  test "the truth" do
    assert true
  end



end
