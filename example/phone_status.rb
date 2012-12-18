require 'tectonics'

class PhoneStatus
  include Donaghy::Service

  receives "phone-bank/users/call_sessions/*/calls/*", :handle_call_change, :version => "v1"

  def handle_call_change(path, evt)
    # the original event published was trigger("phone-bank/users/call_sessions/abc/calls/def", {busy: true})
    # so:
    evt.payload == {busy: true}
    path == "phone-bank/users/call_sessions/abc/calls/def"
    # instance method defined in the base class, or @params
    # maybe?
    params == {call_session_id: "abc", call_id: "def"} # true?

    # DO Work

    global_trigger("got_here/something", payload: "something") #triggers phone_status.got_here - will set the "orig"

    # do work

    #oh no
    raise_system_error("OH NO") #triggers a big ol' alert to us

    raise "unexpected" # will retry the event processing
  end

  def handle_internal_event(path, evt)
    #for inside the system, using the "on" syntax as opposed to the "receives"
  end


end
