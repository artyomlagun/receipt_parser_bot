# Faraday.get("https://api.telegram.org/bot517795478:AAG26NTNYlD0LeMtzFhgCZ4dG61gOKtqZic/setWebhook?url=https://98614396.ngrok.io/bot517795478") - activate webhooks for ngrok
require 'open-uri'
require 'faraday'
require 'zbar'
class TelegramRequestsController < ApplicationController
  skip_before_action  :verify_authenticity_token

  BASIC_URL_TELEGRAM = "https://api.telegram.org/bot517795478:AAG26NTNYlD0LeMtzFhgCZ4dG61gOKtqZic"
  GET_FILE_PATH_URL = "#{BASIC_URL_TELEGRAM}/getFile?file_id="
  GET_FILE_URL = "https://api.telegram.org/file/bot517795478:AAG26NTNYlD0LeMtzFhgCZ4dG61gOKtqZic"

  def send_request
    chat_id = params[:message][:chat][:id]
    user_first_name = params[:message][:from][:first_name]
    message_text = params[:message][:text]
    message_document = params[:message][:document]

    if message_text.present?
      case message_text
        when '/start'
          response_text = "Hello, #{user_first_name}!"
        when '/stop'
          response_text = "Bye!"
        else
          response_text = "Sorry! I could not understand this command."
      end
    else
      if params[:message].dig(:photo)
        image_id = params[:message][:photo].last[:file_id]
      else
        image_id = params[:message][:document][:file_id]
      end
      response = read_image(image_id)
      response_text = "В вашем чеке: \n"
      response['items'].each {|item| response_text += "#{item['name']} - #{item['quantity']} - #{item['price']} \n" }
    end

    do_call(chat_id, response_text)

    render json: {status: :ok}
  end

  private

  def read_image(image_id)
    url = GET_FILE_PATH_URL + image_id
    image = JSON.parse(Faraday.get(URI(url)).body)
    image_info = nil
    image_url = GET_FILE_URL + "/#{image['result']['file_path']}"

    uri = URI(image_url)
    tempfile = Tempfile.new("open-uri", binmode: true)
    downloaded_file = uri.open
    IO.copy_stream(downloaded_file, tempfile.path)
    image_info = ZBar::Image.from_jpeg(File.binread(tempfile)).process[0].data
    parsed_receipt = get_receipt_info(image_info)
    parsed_receipt
  end

  def get_receipt_info(params)
    parsed_params = params.split('&').map {|param| param.split('=')}.to_h
    connection = Faraday.new(nil, {request: {timeout: 60}})
    response = connection.post do |req|
      req.url("#{receipt_parser.parse_url}.json")
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        receipt_info: parsed_params
      }.to_json
    end
    JSON.parse(response.body)
  end

  def do_call(chat_id, response_text)
    connection = Faraday.new(nil, {request: {timeout: 20}})
    response = connection.post do |req|
      req.url(URI('https://api.telegram.org/bot517795478:AAG26NTNYlD0LeMtzFhgCZ4dG61gOKtqZic/sendMessage'))
      req.headers['Content-Type'] = 'application/json'
      req.body = {chat_id: chat_id, text: response_text}.to_json
    end
  end

end
