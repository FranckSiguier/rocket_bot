# frozen_string_literal: true

require 'dotenv/load'
require 'csv'
require 'telegram/bot'

BOT_TOKEN = ENV['BOT_TOKEN']

BASE_URI = 'https://framex-dev.wadrid.net/api/video/Falcon%20Heavy%20Test%20Flight%20(Hosted%20Webcast)-wbSwFU6tY1c/frame/'
TOTAL_FRAMES = 61_696 # for this example but this can be made dynamic
STARTING_FRAME = TOTAL_FRAMES / 2
counter = 1

QUESTION = 'Can you tell me if the rocket has launched ?'

FILEPATH = 'data.csv'
CSV_OPTIONS = { col_sep: ',', force_quotes: true, quote_char: '"' }.freeze

CSV.open(FILEPATH, 'wb', CSV_OPTIONS) do |csv|
  # csv << ['Frame', 'MinFrame', 'MaxFrame', 'Counter']
  csv << [STARTING_FRAME.to_s, 0.to_s, TOTAL_FRAMES.to_s, counter.to_s]
end

def fetch_photo(frame, bot, message)
  puts "Current frame = #{frame}"
  bot.api.send_message(chat_id: message.chat.id, text: QUESTION)
  bot.api.send_photo(chat_id: message.chat.id, photo: BASE_URI + frame.to_s, caption: "'Yes' or 'No'")
end

def endgame(frame, bot, message)
  bot.api.send_photo(chat_id: message.chat.id, photo: BASE_URI + frame.to_s, caption: "Frame number #{frame} is close enough to being the exact frame the rocket takes off")
end

def store_csv(frame, min_frame, max_frame, counter)
  CSV.open(FILEPATH, 'wb', CSV_OPTIONS) do |csv|
    csv << [frame.to_s, min_frame.to_s, max_frame.to_s, counter.to_s]
  end
end

def parse_csv
  CSV.foreach(FILEPATH) do |row|
    puts row
    array = row.map(&:to_i)
    return array
  end
end

Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
  bot.listen do |message|
    case message.text
    when '/start'
      array = parse_csv
      current_frame = array[0]
      bot.api.send_message(chat_id: message.chat.id, text: "Hello, #{message.from.first_name}")
      fetch_photo(current_frame, bot, message)
    when '/stop'
      bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
    when 'No'
      array = parse_csv
      counter = array[3]
      counter += 1
      current_frame = array[0] # We read the current frame from the csv file
      if counter > 15
        endgame(current_frame, bot, message)
      else
        min_frame = current_frame # We update the minimum frame possible for the launch
        max_frame = array[2]
        current_frame += ((max_frame - current_frame) / 2)
        store_csv(current_frame, min_frame, max_frame, counter)
        fetch_photo(current_frame, bot, message)
      end
    when 'Yes'
      array = parse_csv
      counter = array[3]
      counter += 1
      current_frame = array[0]
      if counter > 15
        endgame(current_frame, bot, message)
      else
        min_frame = array[1]
        max_frame = current_frame # We update the maximum frame possible for the launch
        current_frame -= ((current_frame - min_frame) / 2)
        store_csv(current_frame, min_frame, max_frame, counter)
        fetch_photo(current_frame, bot, message)
      end
    else
      bot.api.send_message(chat_id: message.chat.id, text: 'You can type /start to start the process again')
    end
  end
end
