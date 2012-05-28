require 'sinatra'

$repos = []
$repos << {name:"foo",home:"ats-0.2.7"}
$repos << {name:"postiats",home:"ats-0.2.7"}



def replace_pattern str, pattern, replace
  while str.match(pattern) do
    str.gsub!(pattern,replace)
  end
end

def lxr_send_file path
  text = File.open(Dir.pwd+path,"r").read
  haml :regular_file,locals:{text:text}
end

def listing_of_directory directory
  raise Sinatra::NotFound if not File.directory?(directory)
  @directory = Dir.new(directory)
  @entries = @directory.entries
  @entries.sort! 
  haml :directory_listing
end

def xref_of_file path, base
  raise Sinatra::NotFound if not File.exists?(path)
  file_folder = File.dirname(path)
  atsopt_path = "/opt/ats/bin/atsopt"
  flag = ""
  if path.match(/\.dats/)
    flag = "--dynamic"
  end
  if path.match(/\.sats/)
    flag = "--static"
  end
  atsopt = IO.popen("#{atsopt_path} --posmark_xref -IATS #{base} -IATS #{file_folder} #{flag} #{path}")
  atsopt.readlines.join("")
end

def make_xref repo_name, path
  repo = $repos.select do |r|
    r[:name] == repo_name
  end
  raise Sinatra::NotFound if (repo = repo.first).nil?
  ENV["ATSHOME"] = "#{Dir.pwd}/ats/#{repo[:home]}"
  output = xref_of_file "repos/#{repo_name}/#{path}","repos/#{repo_name}"
  #Fix up all the links
  replace_pattern(output,/a href\=\"#{Dir.pwd}\/ats\/#{repo[:home]}\/(.*)\"/,
                  "a href=\"/ats/#{repo[:home]}/\\1\"")
  replace_pattern(output,/a href=\"#{Dir.pwd}\/repos\/(.*)\"/,"a href=\"/\\1\"")
  output
end

def make_xref_ats_source home, path
  ENV["ATSHOME"] = "#{Dir.pwd}/ats/#{home}"
  output = xref_of_file "#{Dir.pwd}/ats/#{home}/#{path}", ENV["ATSHOME"]
  replace_pattern(output,/a href\=\"#{Dir.pwd}\/ats\/#{home}\/(.*)\"/,
                  "a href=\"/ats/#{home}/\\1\"")
  output
end

get '/' do
  haml :index
end

get '/repos' do
  haml :index
end

get '/ats/:home/*' do |home, path|
  rel_path = "ats/#{home}/#{path}"
  return listing_of_directory(rel_path) if File.directory? rel_path
  return lxr_send_file "/ats/#{home}/#{path}" if !path.match(/\.dats/) && !path.match(/\.sats/)
  src = make_xref_ats_source home, path
  haml :ats_source, locals:{source:src,title:path,header:""}
end

get '/:repo/*' do  |repo_name,path|
  rel_path = "repos/#{repo_name}/#{path}"
  return listing_of_directory(rel_path) if File.directory? rel_path
  if File.exists?(rel_path) && !path.match(/\.dats/) && !path.match(/\.sats/)
    return lxr_send_file "/repos/#{repo_name}/#{path}"
  end
  src = make_xref repo_name, path
  haml :ats_source, locals:{source:src}
end
