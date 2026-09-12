require "webmock"
include WebMock::API
WebMock.enable!
require_relative "lib/radfish"

WebMock.reset!
stub_request(:get, "https://bmc.example.com/redfish/v1")
  .to_return(status: 200, body: '{"Product":"X"}', headers: {"X-Auth-Token" => "d34db33f"})

r, w = IO.pipe
pid = fork do
  r.close; STDOUT.reopen(w)
  c = Radfish::HttpClient.new(host: "bmc.example.com", username: "root", password: "S3cret!", verbosity: 3)
  c.get("/redfish/v1", headers: {"X-Auth-Token" => "d34db33f"})
  w.close
end
w.close
out = r.read
Process.wait(pid)

require "base64"
b64 = Base64.strict_encode64("root:S3cret!")
puts "basic-auth base64 (#{b64}) in log: #{out.include?(b64)}"
puts "password literal in log:          #{out.include?('S3cret!')}"
puts "token literal in log:             #{out.include?('d34db33f')}"
puts "--- authorization / token lines ---"
out.each_line { |l| puts "  #{l.chomp}" if l =~ /authorization|auth-token/i }
