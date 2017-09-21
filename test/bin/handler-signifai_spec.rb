require 'json'
require 'net/http'
require_relative '../spec_helper.rb'
require_relative '../../bin/handler-signifai.rb'

# rubocop:disable Style/ClassVars
class SignifaiHandler
  at_exit do
    @@autorun = false
  end

  def settings
    @settings ||= JSON.parse(fixture('signifai_settings.json').read)
  end
end

describe 'Handlers' do
  before do
    @handler = SignifaiHandler.new
  end

  describe '#json_config' do
    it 'should return signifai' do
      expect(@handler.json_config).to eq('signifai')
    end

    it 'should return custom' do
      json_config = SignifaiHandler.new('-j custom_key'.split).json_config
      expect(json_config).to eq('custom_key')
    end
  end

  describe '#api_key' do
    it 'should return base key' do
      io_obj = fixture('minimal_create.json')
      @handler.read_event(io_obj)
      expect(@handler.api_key).to eq('BASE_KEY')
    end
  end

  describe '#incident_with_event' do
    it 'should generate a good incident JSON' do
      # Build a similar request object
      io_obj = fixture('minimal_create.json')
      @handler.read_event(io_obj)
      expected_incident = {
        event_source: 'sensu',
        host: nil,
        service: nil,
        timestamp: 1,
        event_description: nil,
        value: 'critical',
        attributes: {
          state: 'alarm',
          check_type: nil,
          check_name: nil,
          check_command: nil,
          check_subscribers: nil,
          check_interval: nil,
          check_handlers: nil
        }
      }
      expected_incident = JSON.dump(expected_incident)
      expect(@handler.incident_with_state('alarm', 1)).to eq(expected_incident)
    end

    it 'should default to critical if status is an out-of-bounds index' do
      io_obj = fixture('out_of_bounds_status.json')
      @handler.read_event(io_obj)
      expected_incident = {
        event_source: 'sensu',
        host: nil,
        service: nil,
        timestamp: 1,
        event_description: nil,
        value: 'critical',
        attributes: {
          state: 'alarm',
          check_type: nil,
          check_name: nil,
          check_command: nil,
          check_subscribers: nil,
          check_interval: nil,
          check_handlers: nil
        }
      }
      expected_incident = JSON.dump(expected_incident)

      expect(@handler.incident_with_state('alarm', 1)).to eq(expected_incident)
    end
  end

  describe '#handle' do
    it 'should create incident' do
      stub_http_client = double
      io_obj = fixture('minimal_create.json')
      @handler.read_event(io_obj)
      allow(@handler).to receive(:json_config).and_return('signifai')
      allow(@handler).to receive(:event_summary).and_return('test_summary')

      # Build a similar request object
      expected_incident = {
        event_source: 'sensu',
        host: nil,
        service: nil,
        timestamp: 1,
        event_description: nil,
        value: 'critical',
        attributes: {
          state: 'alarm',
          check_type: nil,
          check_name: nil,
          check_command: nil,
          check_subscribers: nil,
          check_interval: nil,
          check_handlers: nil
        }
      }
      expected_incident = JSON.dump(expected_incident)

      expect(stub_http_client).to receive(:use_ssl=).with(true)
      expect(stub_http_client).to receive(:request) do |test_req|
        expect(test_req.body).to eq(expected_incident)
        expect(test_req['Authorization']).to eq('Bearer BASE_KEY')
        expect(test_req.content_type).to eq('application/json')
        expect(test_req.uri).to eq(COLLECTORS_URI)
      end
      @handler.handle(stub_http_client, 1)
    end

    it 'should resolve incident' do
      stub_http_client = double
      io_obj = fixture('minimal_resolve.json')
      @handler.read_event(io_obj)
      allow(@handler).to receive(:json_config).and_return('signifai')
      allow(@handler).to receive(:event_summary).and_return('test_summary')

      # Build a similar request object
      expected_incident = {
        event_source: 'sensu',
        host: nil,
        service: nil,
        timestamp: 1,
        event_description: nil,
        value: 'critical',
        attributes: {
          state: 'ok',
          check_type: nil,
          check_name: nil,
          check_command: nil,
          check_subscribers: nil,
          check_interval: nil,
          check_handlers: nil
        }
      }
      expected_incident = JSON.dump(expected_incident)

      expect(stub_http_client).to receive(:use_ssl=).with(true)
      expect(stub_http_client).to receive(:request) do |test_req|
        expect(test_req.body).to eq(expected_incident)
        expect(test_req['Authorization']).to eq('Bearer BASE_KEY')
        expect(test_req.content_type).to eq('application/json')
        expect(test_req.uri).to eq(COLLECTORS_URI)
      end

      @handler.handle(stub_http_client, 1)
    end
  end
end
