module Donaghy

  describe Service do
    before do
      class BaseService
        include Donaghy::Service
        class_attribute :handler
        self.handler = Queue.new

        receives "sweet/pie", :handle_sweet_pie

        def handle_sweet_pie(path, evt)
          self.class.handler << [path, evt]
        end
      end
    end

    let(:event_path) { "sweet/pie" }
    let(:root_path) { Donaghy.root_event_path }
    let(:event_path_with_root) { "#{root_path}/#{event_path}"}
    let(:base_service) { BaseService.new }

    it "should #root_trigger" do
      EventDistributerWorker.should_receive(:perform_async).with(event_path_with_root, hash_including(payload: "cool")).and_return(true)
      base_service.root_trigger(event_path, payload: "cool")
    end

    it "should #trigger" do
      EventDistributerWorker.should_receive(:perform_async).with("#{root_path}/base_service/#{event_path}", hash_including(payload: "cool")).and_return(true)
      base_service.trigger(event_path, payload: "cool")
    end

    it "should BaseService.subscribe_to_global_events" do
      BaseService.subscribe_to_global_events
      jobs = SubscribeToEventWorker.jobs
      jobs.size.should == 1
      job = jobs.first
      job['args'].should == [event_path, root_path, BaseService.name]

    end


  end


end
