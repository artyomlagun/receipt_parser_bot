# Faraday.get("https://api.telegram.org/bot517795478:AAG26NTNYlD0LeMtzFhgCZ4dG61gOKtqZic/setWebhook?url=https://98614396.ngrok.io/bot517795478") - activate webhooks for ngrok

class TelegramRequestsController < ApplicationController
  skip_before_action  :verify_authenticity_token

  BASIC_URL_TELEGRAM = "https://api.telegram.org/bot517795478:AAG26NTNYlD0LeMtzFhgCZ4dG61gOKtqZic"

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

      CheckReceiptJob.perform_later(chat_id, image_id)

      response_text = 'Спасибо! Чек обрабатывается.'
    end

    do_call(chat_id, response_text)

    render json: {status: :ok}
  end

  private

  def do_call(chat_id, response_text)
    connection = Faraday.new(nil, {request: {timeout: 20}})
    response = connection.post do |req|
      req.url(URI("#{BASIC_URL_TELEGRAM}/sendMessage"))
      req.headers['Content-Type'] = 'application/json'
      req.body = {chat_id: chat_id, text: response_text}.to_json
    end
  end

end
