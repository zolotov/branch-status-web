$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'sinatra'
require 'yaml'
require 'lib/git/lib/gitutils'
require 'jiraSOAP'

configure { @config = YAML.load_file("config.yml") }

configure :development do
	@@repo = GitUtils::Repo.new @config["development"]["git"]["path"],
		@config["development"]["git"]["remote"]
	@@repo.fetch 'origin'
	@@repo.branch.checkout

	@@jira = {}
	@@jira[:user] = @config["development"]["jira"]["user"]
	@@jira[:password] = @config["development"]["jira"]["password"]
end

@widgets = ['jira', 'git']

helpers do 
	def git(branch_name)
		branch_name = branch_name.include?("/") ? branch_name : "origin/#{branch_name}"
		status = {}
		begin
			branch = @@repo.branch(branch_name)			

			last_branch_commit = branch.gcommit
			status["Last commit"] =  last_branch_commit.date.strftime("%d.%m.%Y %I:%M:%S")
			if branch.merged?
				status["Merged"] = branch.merge_commit.date.strftime("%d.%m.%Y %I:%M:%S")
			else
				status["Merged"] = "no"
			end
		rescue
			status["Error"] = "Branch not found"
		end
		status
	end

	def jira(branch_name)
		status = {}
		begin
			jira = JIRA::JIRAService.new 'http://jira.dev'
			jira.login @@jira[:user], @@jira[:password]
			issue = jira.issue_with_key branch_name

			status["Summary"] = issue.summary
			status["Status"] = jira.statuses.select{|status| issue.status_id == status.id}.first.name
		rescue
			status["Error"] = "Issue not found"
		end
		status
	end

	def logger
		request.logger
	end
end

get '/' do
	erb :index
end

post '/' do
	@branch = params[:branch]
	@statuses = {
		'Git' => {:image => "/images/git.png", :status => git(@branch)},
		'JIRA' => {:image => "/images/jira.png", :status => jira(@branch)}
	}
	erb :index
end

get '/jira/:branch' do |branch|
	@title = "JIRA"
	@image = "/images/jira.png"
	@status = jira branch
	erb :widget, :layout => !request.xhr?
end

get '/git/:branch' do |branch|
	@title = "Git"
	@image = "/images/git.png"
	@status = git branch
	erb :widget, :layout => !request.xhr?
end
