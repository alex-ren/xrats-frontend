require 'rubygems'
require 'builder/xchar'

path = ARGV[0]

to_process = IO.popen("find -L #{path} -regextype posix-extended -regex '.*\.(dats|sats)'").readlines if path

index_id = 0

puts <<EOS 
<?xml version="1.0"?>
  <sphinx:docset>
    <sphinx:schema>
      <sphinx:attr name="path" type="string" default="/"/>
      <sphinx:attr name="type" type="string" default="dats"/>
      <sphinx:field name="content"/>
    </sphinx:schema>
  </sphinx:docset>
EOS

to_process.each do |filename|
  contents = File.open(filename.chomp,"r").read
  type = (filename.match(/\.dats/)) ? "dats" : "sats"
  puts <<EOS
<sphinx:document id="#{index_id}">
<content>#{Builder::XChar.encode(contents)}</content>
<path>#{filename}</path>
<type>#{type}</type>
</sphinx:document>
EOS
  index_id += 1
end

puts "</sphinx:docset>"
