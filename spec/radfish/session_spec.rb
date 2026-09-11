require 'spec_helper'

RSpec.describe Radfish::Core::Session do
  class SessionSpecClient < Radfish::Core::BaseClient
    def vendor; 'test'; end
    def login; true; end
    def logout; true; end
  end

  let(:client) do
    SessionSpecClient.new(host: 'bmc.example.com', username: 'root',
                          password: 'S3cret!', port: 443, retry_count: 0)
  end
  let(:session) { described_class.new(client) }
  let(:sessions_url) { 'https://bmc.example.com/redfish/v1/SessionService/Sessions' }

  describe '#create' do
    it 'returns the token on success' do
      stub_request(:post, sessions_url)
        .to_return(status: 201, body: '{"Id":"1"}',
                   headers: { 'X-Auth-Token' => 'tok',
                              'Location' => '/redfish/v1/SessionService/Sessions/1' })

      expect(session.create).to be true
      expect(session.x_auth_token).to eq('tok')
      expect(session.session_id).to eq('1')
    end

    it 'returns false when the BMC refuses' do
      stub_request(:post, sessions_url).to_return(status: 401, body: 'nope')

      expect(session.create).to be false
    end

    # HttpClient turns Faraday failures into Radfish errors, so the rescue here
    # has to catch those, not Faraday::Error.
    it 'returns false when the connection fails' do
      stub_request(:post, sessions_url).to_raise(Faraday::ConnectionFailed.new('refused'))

      expect(session.create).to be false
    end
  end

  describe '#delete' do
    before do
      stub_request(:post, sessions_url)
        .to_return(status: 201, body: '{"Id":"1"}',
                   headers: { 'X-Auth-Token' => 'tok',
                              'Location' => '/redfish/v1/SessionService/Sessions/1' })
      session.create
    end

    it 'clears the token on success' do
      stub_request(:delete, "#{sessions_url}/1").to_return(status: 204)

      expect(session.delete).to be true
      expect(session.x_auth_token).to be_nil
    end

    it 'returns false when the connection fails' do
      stub_request(:delete, "#{sessions_url}/1")
        .to_raise(Faraday::ConnectionFailed.new('refused'))

      expect(session.delete).to be false
    end
  end

  describe '#valid?' do
    it 'is false without a token' do
      expect(session.valid?).to be false
    end
  end
end

RSpec.describe Radfish::HttpClient, 'error boundary and log filters' do
  let(:client) do
    described_class.new(host: 'bmc.example.com', username: 'root',
                        password: 'S3cret!', retry_count: 0)
  end

  it 'raises Radfish errors, not Faraday ones' do
    stub_request(:get, 'https://bmc.example.com/x')
      .to_raise(Faraday::ConnectionFailed.new('refused'))

    expect { client.get('/x') }.to raise_error(Radfish::ConnectionError)
  end

  it 'wraps any other Faraday error too' do
    stub_request(:get, 'https://bmc.example.com/x').to_raise(Faraday::Error.new('odd'))

    expect { client.get('/x') }.to raise_error(Radfish::Error)
  end

  describe 'LOG_FILTERS' do
    def scrub(text)
      described_class.scrub(text)
    end

    it 'redacts the Password in a Redfish session payload' do
      expect(scrub('{"UserName":"root","Password":"S3cret!"}')).not_to include('S3cret!')
    end

    it 'redacts a lowercase json password' do
      expect(scrub('{"password": "S3cret!"}')).not_to include('S3cret!')
    end

    it 'redacts a hash-inspected payload' do
      expect(scrub('{"UserName"=>"root", "Password"=>"S3cret!"}')).not_to include('S3cret!')
    end

    it 'redacts basic auth' do
      expect(scrub('Authorization: Basic cm9vdDpTM2NyZXQh')).not_to include('cm9vdDpTM2NyZXQh')
    end

    it 'redacts the session token in a response header' do
      expect(scrub('x-auth-token: "d34db33f"')).not_to include('d34db33f')
    end

    it 'redacts the session token in a request header hash' do
      expect(scrub('{"X-Auth-Token"=>"d34db33f", "Accept"=>"application/json"}'))
        .not_to include('d34db33f')
    end
  end
end

RSpec.describe Radfish::Core::Session, 'debug output' do
  class SessionLogSpecClient < Radfish::Core::BaseClient
    def vendor; 'test'; end
    def login; true; end
    def logout; true; end
  end

  it 'does not print the session token' do
    client = SessionLogSpecClient.new(host: 'bmc.example.com', username: 'root',
                                      password: 'S3cret!', retry_count: 0)
    client.verbosity = 3
    stub_request(:post, 'https://bmc.example.com/redfish/v1/SessionService/Sessions')
      .to_return(status: 201, body: '{"Id":"1"}',
                 headers: { 'X-Auth-Token' => 'd34db33f',
                            'Location' => '/redfish/v1/SessionService/Sessions/1' })

    session = described_class.new(client)
    output = begin
      old = $stdout
      $stdout = StringIO.new
      session.create
      $stdout.string
    ensure
      $stdout = old
    end

    expect(session.x_auth_token).to eq('d34db33f')
    expect(output).not_to include('d34db33f')
  end
end
