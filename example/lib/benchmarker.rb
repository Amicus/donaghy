class Benchmarker
  include Donaghy::Service

  receives "benchmarker/*", :handle_message_received, :version => "v1"

  def handle_message_received(path, evt)
    if path == "benchmarker/start"
      Donaghy.storage.put("benchmarker_count", 0)
      Donaghy.storage.put("benchmarker_start", (Time.now.to_f * 1000))
    elsif path == "benchmarker/message"
      Donaghy.storage.inc("benchmarker_count")
    else
      Donaghy.storage.set("benchmarker_end", (Time.now.to_f * 1000))
    end
  end

end
