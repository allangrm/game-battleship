# frozen_string_literal: true

require_relative "app/views/main_window"

MainWindow.new.show if $PROGRAM_NAME == __FILE__
