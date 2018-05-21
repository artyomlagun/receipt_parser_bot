Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  mount ReceiptParser::Engine => "/receipt_parser"
  post '/bot517795478', to: 'telegram_requests#send_request', default: {format: :json}

  # root 'telegram_requests#send_request'
end
