#!/usr/bin/env ruby
#
# This handler creates and resolves SignifAi incidents, refreshing
# stale incident details every 30 minutes
#
# Based loosely on the PagerDuty sensu plugin.
#
# Copyright 2017 SignifAI, Inc <support@signifai.io>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# Dependencies:
#
#   sensu-plugin >= 1.0.0
#

require 'sensu-handler'
require 'net/http'

#
# Signifai
#

PRIORITIES = %w[low medium critical critical].freeze
COLLECTORS_URI = URI('https://collectors.signifai.io/v1/incidents')

class SignifaiHandler < Sensu::Handler
  option :json_config,
         description: 'Config Name',
         short: '-j JsonConfig',
         long: '--json_config JsonConfig',
         required: false,
         default: 'signifai'

  def json_config
    @json_config ||= config[:json_config]
  end

  def api_key
    @api_key ||= settings[json_config]['api_key']
  end

  def proxy_settings
    proxy_settings = {}

    proxy_settings['proxy_host']     = settings[json_config]['proxy_host']     || nil
    proxy_settings['proxy_port']     = settings[json_config]['proxy_port']     || 3128
    proxy_settings['proxy_username'] = settings[json_config]['proxy_username'] || ''
    proxy_settings['proxy_password'] = settings[json_config]['proxy_password'] || ''

    proxy_settings
  end

  def incident_with_state(state, time)
    priority_index = if @event['check']['status'].nil? || PRIORITIES[@event['check']['status']].nil?
                       2
                     else
                       @event['check']['status']
                     end

    incident = {
      event_source: 'sensu',
      host: @event['check']['source'] || @event['client']['name'],
      service:  @event['client']['name'],
      timestamp: time,
      event_description: @event['check']['output'],
      value: PRIORITIES[priority_index],
      attributes: {
        state: state,
        check_type: @event['check']['type'],
        check_name: @event['check']['name'],
        check_command: @event['check']['command'],
        check_subscribers: @event['check']['subscribers'].nil? ? nil : @event['check']['subscribers'].join(','),
        check_interval: @event['check']['interval'],
        check_handlers: @event['check']['handlers'].nil? ? @event['check']['handler'] : @event['check']['handlers'].join(',')
      }
    }

    JSON.dump(incident)
  end

  def _http_client(http_client = nil)
    proxy = proxy_settings
    http = if http_client
             http_client
           elsif proxy['proxy_host']
             Net::HTTP.new(COLLECTORS_URI.host, COLLECTORS_URI.port,
                           p_addr: proxy['proxy_host'],
                           p_port: proxy['proxy_port'],
                           p_user: proxy['proxy_username'],
                           p_pass: proxy['proxy_password'])
           else
             Net::HTTP.new(COLLECTORS_URI.host, COLLECTORS_URI.port)
           end
    http.use_ssl = true
    http
  end

  def handle(http_client = nil, time = Time.now.to_i)
    # "Redundant begin" -- the rescue retries the whole function
    # so it's not redundant
    begin # rubocop:disable Style/RedundantBegin
      tries ||= 3
      Timeout.timeout(10) do
        http = _http_client(http_client)

        incident = case @event['action']
                   when 'create', 'flapping'
                     incident_with_state('alarm', time)
                   when 'resolve'
                     incident_with_state('ok', time)
                   end

        begin
          log_host = @event['check']['source'] || @event['client']['name'] || '(none)'
          log_svc = @event['client']['name'] || '(none)'
          http_request = Net::HTTP::Post.new(COLLECTORS_URI)
          http_request.body = incident
          http_request.content_type = 'application/json'
          http_request['Authorization'] = "Bearer #{api_key}"

          http.request(http_request)

          puts 'signifai -- ' + @event['action'].capitalize + 'd incident: ' + log_host + ' / ' + log_svc
        rescue Net::HTTPServerException => error
          if (tries -= 1) > 0
            retry
          else
            puts 'signifai -- failed to ' + @event['action'] + ' incident -- ' + log_host + ' / ' + log_svc + ' -- ' +
                 error.response.code + ' ' + error.response.message + ': ' + error.response.body
          end
        end
      end
    rescue Timeout::Error
      if (tries -= 1) > 0
        retry
      else
        puts 'signifai -- timed out while attempting to ' + @event['action'] + ' a incident -- ' + incident_key
      end
    end
  end
end
