require 'spec_helper'

RSpec.describe Radfish::HttpClient, 'redirects' do
  let(:client) do
    described_class.new(host: 'bmc.example.com', port: 443,
                        username: 'user', password: 'pass')
  end

  describe '#safe_redirect_path' do
    it 'accepts a relative path' do
      expect(client.safe_redirect_path('/redfish/v1/')).to eq('/redfish/v1/')
    end

    it 'keeps the query string' do
      expect(client.safe_redirect_path('/redfish/v1/?x=1')).to eq('/redfish/v1/?x=1')
    end

    it 'accepts an absolute URL for the same endpoint, and returns just the path' do
      expect(client.safe_redirect_path('https://bmc.example.com/redfish/v1/'))
        .to eq('/redfish/v1/')
    end

    it 'refuses another host' do
      expect(client.safe_redirect_path('https://evil.example.com/redfish/v1/')).to be_nil
    end

    it 'refuses another port' do
      expect(client.safe_redirect_path('https://bmc.example.com:8443/redfish/v1/')).to be_nil
    end

    it 'refuses a downgrade to http' do
      expect(client.safe_redirect_path('http://bmc.example.com/redfish/v1/')).to be_nil
    end

    it 'refuses an empty or pathless location' do
      expect(client.safe_redirect_path(nil)).to be_nil
      expect(client.safe_redirect_path('')).to be_nil
      expect(client.safe_redirect_path('https://bmc.example.com')).to be_nil
    end
  end

  describe '#get' do
    it 'follows a redirect that stays on this endpoint' do
      stub_request(:get, 'https://bmc.example.com/redfish/v1')
        .to_return(status: 301, headers: { 'Location' => '/redfish/v1/' })
      stub_request(:get, 'https://bmc.example.com/redfish/v1/')
        .to_return(status: 200, body: '{"ok":true}')

      response = client.get('/redfish/v1')

      expect(response.status).to eq(200)
      expect(response.body).to eq('{"ok":true}')
    end

    it 'does not send credentials to a host the BMC redirects to' do
      stub_request(:get, 'https://bmc.example.com/redfish/v1')
        .to_return(status: 302,
                   headers: { 'Location' => 'https://evil.example.com/redfish/v1/' })
      evil = stub_request(:get, 'https://evil.example.com/redfish/v1/')
             .to_return(status: 200, body: '{"ok":true}')

      response = client.get('/redfish/v1')

      expect(response.status).to eq(302)
      expect(evil).not_to have_been_requested
    end

    it 'gives up after max_redirects hops' do
      stub_request(:get, 'https://bmc.example.com/a')
        .to_return(status: 301, headers: { 'Location' => '/b' })
      stub_request(:get, 'https://bmc.example.com/b')
        .to_return(status: 301, headers: { 'Location' => '/c' })
      stub_request(:get, 'https://bmc.example.com/c')
        .to_return(status: 301, headers: { 'Location' => '/d' })
      last = stub_request(:get, 'https://bmc.example.com/d')
             .to_return(status: 200, body: '{"ok":true}')

      expect(client.get('/a').status).to eq(200)
      expect(last).to have_been_requested

      client.max_redirects = 2
      expect(client.get('/a').status).to eq(301)
    end

    it 'returns the 3xx itself when the caller passes max_redirects: 0' do
      stub_request(:get, 'https://bmc.example.com/redfish/v1')
        .to_return(status: 301, headers: { 'Location' => '/redfish/v1/' })
      onward = stub_request(:get, 'https://bmc.example.com/redfish/v1/')
               .to_return(status: 200, body: '{"ok":true}')

      response = client.get('/redfish/v1', max_redirects: 0)

      expect(response.status).to eq(301)
      expect(onward).not_to have_been_requested
    end
  end

  describe '#post' do
    it 'does not follow a redirect, because the method would change' do
      stub_request(:post, 'https://bmc.example.com/redfish/v1/Actions/Thing')
        .to_return(status: 302, headers: { 'Location' => '/somewhere' })
      onward = stub_request(:get, 'https://bmc.example.com/somewhere')

      response = client.post('/redfish/v1/Actions/Thing', body: '{}')

      expect(response.status).to eq(302)
      expect(onward).not_to have_been_requested
    end
  end
end

RSpec.describe Radfish::VendorDetector, 'service root redirects' do
  let(:detector) do
    described_class.new(host: 'bmc.example.com', username: 'user',
                        password: 'pass', port: 443)
  end
  let(:service_root) { { 'Product' => 'AMI MegaRAC' }.to_json }

  it 'detects the vendor through a /redfish/v1 -> /redfish/v1/ redirect' do
    stub_request(:get, 'https://bmc.example.com/redfish/v1')
      .to_return(status: 301, headers: { 'Location' => '/redfish/v1/' })
    stub_request(:get, 'https://bmc.example.com/redfish/v1/')
      .to_return(status: 200, body: service_root,
                 headers: { 'Content-Type' => 'application/json' })

    expect(detector.detect).to eq('ami')
  end

  it 'fails cleanly when the redirect leaves the endpoint' do
    stub_request(:get, 'https://bmc.example.com/redfish/v1')
      .to_return(status: 302,
                 headers: { 'Location' => 'https://evil.example.com/redfish/v1/' })
    evil = stub_request(:get, 'https://evil.example.com/redfish/v1/')
           .to_return(status: 200, body: service_root)

    expect(detector.detect).to be_nil
    expect(evil).not_to have_been_requested
  end
end
