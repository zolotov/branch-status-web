$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'sinatra'
require 'yaml'
require 'lib/git/lib/gitutils'
require 'jiraSOAP'

configure { @config = YAML.load_file("config/config.yml") }

configure do
	@@repo = GitUtils::Repo.new @config["git"]["path"],
		@config["git"]["remote"]

	@@jira = {}
	@@jira[:user] = @config["jira"]["user"]
	@@jira[:password] = @config["jira"]["password"]
end

configure do
	@@repo.fetch 'origin'
	@@repo.branch.checkout
end

helpers do 
	def git(branch_name)
		branch_name = branch_name.include?("/") ? branch_name : "origin/#{branch_name}"
		status = {}
		begin
			branch = @@repo.branch(branch_name)			

			last_branch_commit = branch.gcommit
			status["Last commit"] =  last_branch_commit.date.strftime("%d.%m.%Y %H:%M:%S")
			if branch.merged?
				status["Merged"] = branch.merge_commit.date.strftime("%d.%m.%Y %H:%M:%S")
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
	@branch = params[:branch]
	unless @branch.nil?
		@statuses = {
			'Git' => {:image => "/images/git.png", :status => git(@branch)},
			'JIRA' => {:image => "/images/jira.png", :status => jira(@branch)}
		}
	end

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
