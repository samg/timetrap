def with_stubbed_config(options = {})
  defaults = Timetrap::Config.defaults.dup
  allow(Timetrap::Config).to receive(:[]) do |k|
    defaults.merge(options)[k]
  end
  yield if block_given?
end
