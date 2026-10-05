# frozen_string_literal: true

require_relative "test_helper"

class RuntimeTest < Minitest::Test
  def test_keeps_scheduler_alive_and_shuts_it_down_explicitly
    scheduler = Struct.new(:shutdown_argument) do
      def shutdown(argument)
        self.shutdown_argument = argument
      end
    end.new
    app = ->(_environment) { [204, {}, []] }
    runtime = RunpodGpuAvailability::Runtime.new(app: app, scheduler: scheduler)

    assert_same scheduler, runtime.scheduler
    assert_equal 204, runtime.call({}).first
    runtime.close

    assert_equal :wait, scheduler.shutdown_argument
  end

  def test_close_is_safe_without_a_scheduler
    runtime = RunpodGpuAvailability::Runtime.new(app: ->(_environment) { [204, {}, []] }, scheduler: nil)

    assert_nil runtime.close
  end
end
