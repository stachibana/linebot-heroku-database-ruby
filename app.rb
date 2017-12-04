require 'sinatra'
require 'line/bot'
require 'json'
require 'pg'
require 'sinatra/sequel'

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV['CHANNEL_SECRET']
    config.channel_token = ENV['CHANNEL_ACCESS_TOKEN']
  }
end

post '/' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)
  events.each { |event|
    if event['type'] == 'message' then
      if event['message']['type'] == 'text' then
        if event['message']['text'] == 'last' then
          db = Sequel.connect(ENV['DATABASE_URL'])
          result = db[:users].select(:lastmessage).where(userid: event['source']['userId']).first
          if result.count > 0 then
            message = [
              {
                type: 'text',
                text: result[:lastmessage]
              }
            ]
            client.reply_message(event['replyToken'], message)
          else
            message = [
              {
                type: 'text',
                text: 'no history'
              }
            ]
            client.reply_message(event['replyToken'], message)
          end
        else
          db = Sequel.connect(ENV['DATABASE_URL'])
          db[:users].insert_conflict(target: :userid, update: {lastmessage: event['message']['text']}).insert(userid: event['source']['userId'], lastmessage: event['message']['text'])
          message = [
            {
              type: 'text',
              text: 'Message saved. Send \'last\' to show.'
            }
          ]
          client.reply_message(event['replyToken'], message)
        end
      end
    end
  }
  "OK"

end
