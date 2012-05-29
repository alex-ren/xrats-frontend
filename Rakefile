task :default => :index_repositories

task :index_repositories do
  sh "indexer --config config/sphinx.conf --all --rotate"
end
