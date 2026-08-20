# frozen_string_literal: true

require "minitest/autorun"
require_relative "../app/controllers/menu_controller"

class MenuControllerTest < Minitest::Test
  class FakeWindow
    attr_reader :destination

    def navigate_to(destination)
      @destination = destination
    end

    def close
      @closed = true
    end

    def closed?
      @closed == true
    end
  end

  def setup
    @window = FakeWindow.new
    @controller = MenuController.new(@window)
  end

  def test_routes_every_menu_option
    {
      start_game: :name,
      show_ranking: :ranking,
      show_instructions: :instructions
    }.each do |action, destination|
      @controller.handle(action)
      assert_equal destination, @window.destination
    end
  end

  def test_exit_closes_the_window
    @controller.handle(:exit)

    assert @window.closed?
  end

  def test_rejects_an_unknown_action
    assert_raises(ArgumentError) { @controller.handle(:unknown) }
  end
end
