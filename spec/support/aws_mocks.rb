module AwsMocks
  def stub_ses_client(responses = {})
    client = Aws::SES::Client.new(stub_responses: true)
    responses.each do |operation, output|
      client.stub_responses(operation, output)
    end

    client
  end
end

RSpec.configure do |config|
  config.include AwsMocks
end
