require 'sinatra'

require 'yaml'
require 'json'
require 'riddle'
require 'open4'
require 'shellwords'

$app_config = YAML.load_file("config/app.yml")[ENV['RACK_ENV']]
$repos = YAML.load_file("config/repos.yml")["repos"]
$ats = YAML.load_file("config/ats.yml")["versions"]

$sphinx = Riddle::Client.new

helpers do
  include Rack::Utils
end

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
  pats2html_path = "/opt/postiats/utils/atsyntax/pats2html" #For ATS2
  flag = ""
  if path.match(/\.dats/)
    flag = "--dynamic"
  end
  if path.match(/\.sats/)
    flag = "--static"
  end
  if File.exists? file_folder+"/.ats2"
    ENV["PATSHOME"] = "/opt/postiats"
    input = File.open(path).read()
    res = ""
    status = Open4::popen4(pats2html_path+" "+flag) do |pid,stdin,stdout,stderr|
      stdin.puts(input)
      stdin.close
      res = stdout.read
    end
    res
  else
    `#{atsopt_path} --posmark_xref -IATS #{base} -IATS #{file_folder} #{flag} #{path}`
  end
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
  replace_pattern(output,/a href=\"#{Dir.pwd}\/ats\/#{ats_home}\/(.*)\"/,"a href=\"/ats/#{ats_home}/\\1\"")
  replace_pattern(output,/a href=\"#{Dir.pwd}\/repos\/(.*)\"/,"a href=\"/repos/\\1\"")
  output
end

post '/:compiler/:action' do |compiler,action|
  content_type :json
  res = ""
  compiler = Shellwords.escape(compiler)
  flags = []
  case action
  when "typecheck"
    flags << "--tc"
  when "compile"
    nil
  else
    raise Sinatra::NotFound
  end
  jailed_command = "lib/atscc-jailed --compiler #{compiler} #{flags.join(" ")}"
  status = Open4::popen4(jailed_command) do |pid,stdin,stdout,stderr|
    stdin.puts(params[:input])
    stdin.close
    res = stdout.read
  end
  res = escape_html res
  if status.to_i != 0
    res = "Killed" if res.empty?
  end
  #Add formatting for syntax errors.
  error_replacement = "<button class=\"syntax-error\" data-line=\"\\1\" data-char=\"\\2\">line=\\1, offs=\\2</button>"
  formatted = res.split("\n")
  formatted.map! do |line|
    if /^&#x2F;tmp/.match(line) #patsopt throws errors in the prelude, only want ours.
      replace_pattern(line,/\(line=(\d+), offs=(\d+)\)/,error_replacement)
    end
    line
  end
  res = formatted.join("\n")
  {status:status.to_i,output:res}.to_json
end

get '/application.js' do
  #cache_control :public, max_age:"86400"
  coffee :application
end

get %r{^/(ats|repos)??/?$} do
  cache_control :public, max_age:"86400"
  haml :index
end

get "/code/:compiler" do |compiler|
  actions = []
  canned = ""
  title = ""
  case compiler 
  when "ats"
    title = "ATS"
    canned = open("config/helloworld.dats").read()
    actions = ["typecheck","compile"]
  when "patsopt"
    title = "ATS2"
    canned = open("config/fibonacci.dats").read()
    actions = ["typecheck"]
  else 
    raise Sinatra::NotFound
  end
  haml :code, locals:{compiler:compiler,actions:actions,canned:canned,title:title}
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
