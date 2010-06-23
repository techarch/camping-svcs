#gem 'camping' , '>= 1.9.354'
gem 'camping' , '>= 2.0'
require 'active_record'

require 'rack'

gem 'markaby' , '= 0.5'

require 'camping'
require 'camping/session'
require 'camping/reloader'

use_camping_reloader = true
if use_camping_reloader
	reloader = Camping::Reloader.new('camping-svcs.rb')
	#puts "reloader.apps=#{reloader.inspect}"
	blog = reloader.apps[:CampingRestServices]
else
	require 'camping-svcs.rb'
	blog =Rack::Adapter::Camping.new(CampingRestServices)
end
#---------------------------------------------

use Rack::Reloader

use Rack::Static, 
	:urls => [ '/static', 
					'/static/css', 
					'/static/css/ui-lightness', 
					'/static/css/ui-lightness/images', 
					'/static/img', 
					'/static/js' ], 
	:root => File.expand_path(File.dirname(__FILE__))


environment = ENV['DATABASE_URL'] ? 'production' : 'development'

run blog		#from the command line: rackup config.ru -p 3301
