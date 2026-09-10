require 'spec_helper'

RSpec.describe Radfish::HttpClient, 'retries' do
  def client(**overrides)
    described_class.new(host: 'bmc.example.com', username: 'root', password: 'pw',
                        retry_count: 2, retry_delay: 0, **overrides)
  end

  it 'retries a GET that fails with a server error' do
    attempts = 0
    stub_request(:get, 'https://bmc.example.com/x')
      .to_return { attempts += 1; { status: 503, body: 'busy' } }

    expect(client.get('/x').status).to eq(503)
    expect(attempts).to eq(3) # the first try plus retry_count
  end

  # A repeated POST can mean a second session, a second reset, a second job.
  it 'does not retry a POST' do
    attempts = 0
    stub_request(:post, 'https://bmc.example.com/x')
      .to_return { attempts += 1; { status: 503, body: 'busy' } }

    expect(client.post('/x', body: '{}').status).to eq(503)
    expect(attempts).to eq(1)
  end

  it 'does not retry a PATCH' do
    attempts = 0
    stub_request(:patch, 'https://bmc.example.com/x')
      .to_return { attempts += 1; { status: 500, body: 'boom' } }

    expect(client.patch('/x', body: '{}').status).to eq(500)
    expect(attempts).to eq(1)
  end

  it 'retries a POST when the caller asks for it' do
    attempts = 0
    stub_request(:post, 'https://bmc.example.com/x')
      .to_return { attempts += 1; { status: 503, body: 'busy' } }

    wide = client(retry_methods: described_class::IDEMPOTENT_METHODS + [:post])
    expect(wide.post('/x', body: '{}').status).to eq(503)
    expect(attempts).to eq(3)
  end

  it 'retries a connection failure on a GET, then gives up with a Radfish error' do
    attempts = 0
    stub_request(:get, 'https://bmc.example.com/x')
      .to_raise(Faraday::ConnectionFailed.new('refused'))
      .to_raise(Faraday::ConnectionFailed.new('refused'))
      .to_raise(Faraday::ConnectionFailed.new('refused'))

    expect { client.get('/x') }.to raise_error(Radfish::ConnectionError)
  end

  it 'defaults to the idempotent set' do
    expect(client.retry_methods).to eq(described_class::IDEMPOTENT_METHODS)
    expect(client.retry_methods).not_to include(:post, :patch)
  end
end
