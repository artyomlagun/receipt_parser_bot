require 'open-uri'
require 'faraday'
require 'zbar'
require 'json'

class CheckReceiptJob < ApplicationJob
  queue_as :default

  BASIC_URL_TELEGRAM = "https://api.telegram.org/bot517795478:AAG26NTNYlD0LeMtzFhgCZ4dG61gOKtqZic"
  GET_FILE_PATH_URL = "#{BASIC_URL_TELEGRAM}/getFile?file_id="
  GET_FILE_URL = "https://api.telegram.org/file/bot517795478:AAG26NTNYlD0LeMtzFhgCZ4dG61gOKtqZic"
  REGEXP = /t=[0-9T]+&s=[0-9]{0,9}.[0-9]{2}&fn=[0-9]{14,20}&i=[0-9]+&fp=[0-9]{8,16}&n=[0-9]+/i

  SOMETHING_WENT_WRONG_MSG = 'Что-то пошло не так. Повторите попытку.'
  INVALID_RECEIPT_MSG = 'Чек некорректен! Попробуйте ещё раз или другой чек.'

  def perform(chat_id, image_id)
    image_info = read_image(image_id)

    if image_info.nil?
      send_receipt_info(chat_id, INVALID_RECEIPT_MSG)
    else
      if image_info =~ REGEXP
        receipt_info = get_receipt_info(image_info)
      else
        receipt_info = INVALID_RECEIPT_MSG
      end
      send_receipt_info(chat_id, receipt_info)
    end
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
    image_info = ZBar::Image.from_jpeg(File.binread(tempfile)).process[0]
    unless image_info.nil?
      image_info = image_info.data
    end
    image_info
  end

  def get_receipt_info(params)
    parsed_params = params.split('&').map {|param| param.split('=')}.to_h
    begin
      connection = Faraday.new('https://receipt-parser-bottington.herokuapp.com', {request: {timeout: 40}})
      response = connection.post do |req|
        req.url("/receipt_parser/parse.json")
        req.headers['Content-Type'] = 'application/json'
        req.body = {
          receipt_info: parsed_params
        }.to_json
      end

      information = JSON.parse(response.body)

      if information.nil?
        response_text = SOMETHING_WENT_WRONG_MSG
      else
        response_text = "В вашем чеке: \n"
        information['items'].each {|item| response_text += "#{item['name']} - #{item['quantity']} - #{item['price']} \n" }
      end
    rescue Faraday::Error => err
      response_text = SOMETHING_WENT_WRONG_MSG
    end
    response_text
  end

  def send_receipt_info(chat_id, response_text)
    connection = Faraday.new(nil, {request: {timeout: 20}})
    response = connection.post do |req|
      req.url("#{BASIC_URL_TELEGRAM}/sendMessage")
      req.headers['Content-Type'] = 'application/json'
      req.body = {chat_id: chat_id, text: response_text}.to_json
    end
  end
end
