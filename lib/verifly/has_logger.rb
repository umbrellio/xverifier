# frozen_string_literal: true

require "logger"

module Verifly
  # Mixin with logger attr_accessor and default value for it
  # @!attribute logger
  #   @return [::Logger] logger to be used within target module
  module HasLogger
    # Does nothing, provides ::Logger api
    class NullLogger < ::Logger
      # @api stdlib
      def initialize
        super(nil)
      end

      # @api stdlib
      # Logs nothing
      def add(*); end
    end

    attr_writer :logger

    def logger
      @logger ||= NullLogger.new
    end
  end
end
