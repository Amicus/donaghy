class ExampleListener
  include Donaghy::Service

  receives "benchmarker/*", :handle_message_received, :version => "v1"

  def handle_message_received(path, evt)
    if path == "benchmarker/start"
      Donaghy.redis.with do |conn|
        conn.set("benchmarker_count", 0)
        conn.set("benchmarker_start", Time.now.to_i)
      end
    elsif path == "benchmarker/message"
      Donaghy.redis.with {|conn| conn.incr("benchmarker_count")}
    else
      Donaghy.redis.with {|conn| conn.set("benchmarker_end", Time.now.to_i)}
    end
  end

end
