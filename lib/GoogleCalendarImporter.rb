require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'google-apis-calendar_v3'
require 'pry-byebug'

class GoogleCalendarImporter

  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'

  def initialize(credentials_file)
    scope = 'https://www.googleapis.com/auth/calendar.events.readonly'
    client_id = Google::Auth::ClientId.from_file(credentials_file)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: 'token.yaml')
    authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)
    
    user_id = 'joshtimetracker'
    @credentials = authorizer.get_credentials(user_id)
    if @credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI )
      puts "Open #{url} in your browser and enter the resulting code:"
      code = gets
      @credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI)
    end
  end

  def hours_to_minutes(hours)
    hours_part = hours.to_i
    minutes_part = ((hours - hours_part) * 60).to_i
    "#{hours_part}:#{format('%02d', minutes_part)}"
  end

  def get_events(calendar_id)
    # Time should be formatted in the following:
    # '2023-02-13 15:35'
    # DateTime.parse('2023-02-13 15:35').to_s will provide the proper formatted string
    start_date = DateTime.now - 7
    @calendar = Google::Apis::CalendarV3::CalendarService.new
    @calendar.authorization = @credentials
    events = @calendar.list_events(calendar_id, single_events: true, order_by: 'startTime', time_min: start_date)
    # binding.pry
    events.items.map do |event|
      {
        summary: event.summary,
        start_time: event.start.date_time || event.start.date,
        end_time: event.end.date_time || event.end.date,
        length: hours_to_minutes((event.end.date_time.to_time - event.start.date_time.to_time) / 3600)
      }
    end
  end
end