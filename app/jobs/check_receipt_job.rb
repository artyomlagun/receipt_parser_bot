require 'open-uri'
require 'faraday'
require 'zbar'
require 'json'

class CheckReceiptJob < ApplicationJob
  queue_as :default

  BASIC_URL_TELEGRAM = "https://api.telegram.org/bot517795478:AAG26NTNYlD0LeMtzFhgCZ4dG61gOKtqZic"
  GET_FILE_PATH_URL = "#{BASIC_URL_TELEGRAM}/getFile?file_id="
  GET_FILE_URL = "https://api.telegram.org/file/bot517795478:AAG26NTNYlD0LeMtzFhgCZ4dG61gOKtqZic"

  def perform(chat_id, image_id)
    image_info = read_image(image_id)

    receipt_info = get_receipt_info(image_info)

    send_receipt_info(chat_id, receipt_info)
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
    image_info
  end

  def get_receipt_info(params)
    parsed_params = params.split('&').map {|param| param.split('=')}.to_h
    connection = Faraday.new('https://receipt-parser-bottington.herokuapp.com', {request: {timeout: 40}})
    response = connection.post do |req|
      req.url("/receipt_parser/parse.json")
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        receipt_info: parsed_params
      }.to_json
    end

    JSON.parse(response.body)
  end

  def send_receipt_info(chat_id, receipt_info)
    response_text = "В вашем чеке: \n"
    receipt_info['items'].each {|item| response_text += "#{item['name']} - #{item['quantity']} - #{item['price']} \n" }

    connection = Faraday.new(nil, {request: {timeout: 20}})
    response = connection.post do |req|
      req.url(URI("#{BASIC_URL_TELEGRAM}/sendMessage"))
      req.headers['Content-Type'] = 'application/json'
      req.body = {chat_id: chat_id, text: response_text}.to_json
    end
  end
end
