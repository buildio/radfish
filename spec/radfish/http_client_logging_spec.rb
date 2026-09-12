require 'spec_helper'
require 'base64'
require 'stringio'

# These assert against what the Faraday logger really writes, not against
# hand-written sample lines. A filter regex that looks right against an invented
# string can still miss the real format -- that is how
# `Authorization: "Basic ..."` stayed in the clear while a unit test on the
# pattern passed.
RSpec.describe Radfish::HttpClient, 'debug logging' do
  let(:log) { StringIO.new }
  let(:password) { 'S3cret!' }
  let(:token) { 'd34db33f' }
  let(:basic) { Base64.strict_encode64("root:#{password}") }

  def client(verbosity)
    described_class.new(host: 'bmc.example.com', username: 'root',
                        password: password, verbosity: verbosity,
                        retry_count: 0, log_device: log)
  end

  before do
    stub_request(:get, 'https://bmc.example.com/redfish/v1')
      .to_return(status: 200, body: '{"Product":"X"}',
                 headers: { 'X-Auth-Token' => token })
    stub_request(:post, 'https://bmc.example.com/redfish/v1/SessionService/Sessions')
      .to_return(status: 201, body: '{"Id":"1"}', headers: { 'X-Auth-Token' => token })
  end

  context 'at verbosity 2 (headers)' do
    it 'does not log the basic auth credentials' do
      client(2).get('/redfish/v1', headers: { 'X-Auth-Token' => token })

      expect(log.string).to include('Authorization')
      expect(log.string).not_to include(basic)
      expect(log.string).to match(/Authorization: "Basic \[FILTERED\]"/)
    end

    it 'does not log the session token' do
      client(2).get('/redfish/v1', headers: { 'X-Auth-Token' => token })

      expect(log.string).not_to include(token)
    end
  end

  context 'at verbosity 3 (bodies)' do
    it 'does not log a password sent in a session payload' do
      client(3).post('/redfish/v1/SessionService/Sessions',
                     body: { UserName: 'root', Password: password }.to_json)

      expect(log.string).to include('UserName')
      expect(log.string).not_to include(password)
    end

    it 'still logs enough to be useful' do
      client(3).get('/redfish/v1', headers: { 'X-Auth-Token' => token })

      expect(log.string).to include('redfish/v1')
      expect(log.string).to include('Product')
    end
  end

  it 'writes nothing below verbosity 2' do
    client(1).get('/redfish/v1')

    expect(log.string).to be_empty
  end
end
