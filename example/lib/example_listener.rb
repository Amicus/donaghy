class ExampleListener
  include Donaghy::Service

  receives "example_listener/*", :handle_message_received, :version => "v1"

  def handle_message_received(path, evt)
    # the original event published was trigger("phone-bank/users/call_sessions/abc/calls/def", {busy: true})
    # so:
    logger.info("payload: #{evt.payload}")
    logger.info("path: #{path}")
    # instance method defined in the base class, or @params
    # maybe?

    # DO Work some work, trigger things

    root_trigger("got_here/something", payload: "something") #triggers phone_status.got_here - will set the "orig"

    # do work

    #oh no
    raise_system_error("OH NO") #triggers a big ol' alert to us

    raise "unexpected" # will retry the event processing
  end

  def handle_internal_event(path, evt)
    #for inside the system, using the "on" syntax as opposed to the "receives"
  end


end
