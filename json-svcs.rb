gem 'camping' , '>= 2.0'	
%w(rubygems active_support active_support/json active_record camping camping/session markaby erb  ).each { | lib | require lib }

Camping.goes :CampingJsonServices

module CampingJsonServices
	include Camping::Session

	def CampingJsonServices.create
	end

	module CampingJsonServices::Controllers

		class APIDateToday < R '/datetoday'
			def get
				@result = {:today=>Date.today.to_s}
				
				@headers['Content-Type'] = "application/json"
				@result.to_xml(:root=>'response')
			end
		end

		class APITimeNow < R '/timenow'
			def get
				@result = {:now=>Time.now.utc.to_s}
				
				@headers['Content-Type'] = "application/json"
				@result.to_json
			end
		end

	end
end	
