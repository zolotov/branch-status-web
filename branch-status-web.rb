$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'sinatra'
require 'yaml'
require 'lib/git/lib/gitutils'
require 'jiraSOAP'

configure { @config = YAML.load_file("config/config.yml") }

configure do
	@@repo = GitUtils::Repo.new @config["git"]["path"],
		@config["git"]["remote"]

	@@jira_config = {}
	@@jira_config[:url] = @config["jira"]["url"]
	@@jira_config[:user] = @config["jira"]["user"]
	@@jira_config[:password] = @config["jira"]["password"]
end

configure do
	@@repo.fetch 'origin'
	@@repo.branch.checkout
end

helpers do 
	def branch(branch_name)
		branch_name = branch_name.include?("/") ? branch_name : "origin/#{branch_name}"
		@@repo.branch(branch_name)
	end

	def git_timeline(branch_name)
		timeline = {}
		begin
			branch = branch(branch_name)
			last_branch_commit = branch.gcommit
			timeline[last_branch_commit.date] = { :action => "Last commit", :author => last_branch_commit.author.name }
			if branch.merged?
				merge_commit = branch.merge_commit
				unless merge_commit.nil?
					timeline[merge_commit.date] = { :action => "Merge", :author => merge_commit.author.name }
				end
			end
		rescue
		end

		timeline
	end

	def jira_service
		@@jira ||= nil
		if(@@jira.nil?)
			@@jira = JIRA::JIRAService.new @@jira_config[:url]
			@@jira.login @@jira_config[:user], @@jira_config[:password]
		end
		@@jira
	end

	def jira_timeline(branch_name)
		timeline = {}
		begin
			issue = jira_service.issue_with_key branch_name
			timeline[issue.create_time] = { :action => "Create issue", :author => issue.reporter_username }
			unless issue.create_time == issue.last_updated_time
				timeline[issue.last_updated_time] = { :action => "Update issue" } 
			end
		rescue
			p $!
		end

		timeline
	end
end

get '/' do
	@branch_name = params[:branch]
	@branch = branch @branch_name
	@status = @branch.merged? ? "Merged" : "Not merged"
	erb :index
end

get '/timeline/:branch' do |branch_name|
	@timeline = {}
	@timeline.merge! jira_timeline branch_name
	@timeline.merge! git_timeline branch_name
	@timeline.sort

	erb :timeline, :layout => !request.xhr?
end
