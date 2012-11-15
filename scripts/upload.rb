#!/usr/bin/env ruby

require 'faraday'

if ARGV.length < 3
  puts "usage: secret name file"
  exit 1
end

payload = ""

File.open(ARV[2], "r") do |f|
  payload = f.read()
end

resp = Faraday.post "http://xrats.illtyped.com/trial", {
  secret: ARGV[0], name: ARGV[1], events: payload
}

puts resp.body
