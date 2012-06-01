require 'sinatra'

require 'yaml'
require 'json'
require 'riddle'

$repos = YAML.load_file("config/repos.yml")["repos"]
$ats = YAML.load_file("config/ats.yml")["versions"]

$sphinx = Riddle::Client.new

def replace_pattern str, pattern, replace
  while str.match(pattern) do
    str.gsub!(pattern,replace)
  end
end

def lxr_send_file path, browser=true
  text = File.open(path,"r").read
  if browser
    haml :regular_file, locals:{text:text,title:"ATS LXR - "+path}
  else
    #Let nginx send the file
    response.headers['Content-Type'] = "text/plain"
    cache_control :public, max_age:"3600"
    response.headers['X-Accel-Redirect'] = "/protected/#{path}"
  end
end

def listing_of_directory directory
  raise Sinatra::NotFound if not File.directory?(directory)
  @directory = Dir.new(directory)
  @entries = @directory.entries
  @entries.sort!
  haml :directory_listing, locals:{title:"ATS LXR - "+@directory.to_path}
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
  `#{atsopt_path} --posmark_xref -IATS #{base} -IATS #{file_folder} #{flag} #{path}`
end

def make_xref folder,repo,path
  ats_home = ""
  base = ""
  case folder
  when "repos"
    $repos.each do |name,attr|
      if name == repo
        ats_home= attr["ats"]
        break
      end
    end
    base = "repos/#{repo}"
  when "ats"
    @repos << repo if not @repos.include?(repo)
    ats_home = repo
    base = "ats/#{ats_home}"
  else
    raise Sinatra::NotFound
  end
  ENV["ATSHOME"] = "#{Dir.pwd}/ats/#{ats_home}"
  output = xref_of_file "#{folder}/#{repo}/#{path}", base
  replace_pattern(output,/a href\=\"#{Dir.pwd}\/ats\/#{ats_home}\/(.*)\"/,"a href=\"/ats/#{ats_home}/\\1\"")
  replace_pattern(output,/a href=\"#{Dir.pwd}\/repos\/(.*)\"/,"a href=\"/repos/\\1\"")
  output
end

post '/atscc/:action' do |action|
  content_type :json
  case action 
  when "typecheck"
    {status:0,output:"Your file is successfully typechecked!\n"}.to_json
  when "compile"
    {status:0,output:"Hello World!\n"}.to_json
  end
end

get '/application.js' do
  cache_control :public, max_age:"86400"
  coffee :application
end

get %r{^/(ats|repos)??/?$} do 
  cache_control :public, max_age:"86400"
  haml :index
end

get "/code" do
  haml :code
end

get "/search" do
  cache_control :public, max_age:"600"
  $sphinx.offset = params["offset"] if params["offset"]
  results = $sphinx.query(params["query"], params["indexes"])
  haml :search_results, layout:false, locals:{results:results}
end

get %r{^/(download/)?(ats|repos)/(.*?)/(.*)} do |dflag,folder,repo,path|
  cache_control :public, max_age:"600"
  @repos = [repo]
  match = $repos.select {|name,attr| name == repo}
  @repos << match[repo]["ats"] if !match.empty?
  @rel_path = "#{folder}/#{repo}/#{path}"
  raise Sinatra::NotFound if not File.exists? @rel_path
  return lxr_send_file @rel_path, false if dflag
  return listing_of_directory(@rel_path) if File.directory? @rel_path
  if !path.match(/\.dats/) && !path.match(/\.sats/)
    return lxr_send_file @rel_path
  end
  src = make_xref folder,repo,path
  haml :ats_source, locals:{source:src,title:path}
end
