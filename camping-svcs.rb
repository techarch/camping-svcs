gem 'camping' , '>= 2.0'	
%w(rubygems active_support active_support/json active_record camping camping/session markaby erb reststop ).each { | lib | require lib }

Camping.goes :CampingRestServices

module CampingRestServices
	include Camping::Session
	include Reststop
 
	Controllers.extend Reststop::Controllers

	def CampingRestServices.create	
		dbconfig = YAML.load(File.read('config/database.yml'))								
		Camping::Models::Base.establish_connection  dbconfig['development']		

		CampingRestServices::Models.create_schema :assume => (CampingRestServices::Models::Post.table_exists? ? 1.0 : 0.0)
	end
end
	
module CampingRestServices::Base
  alias camping_render render
  alias camping_lookup lookup	# @techarch: required if camping > 2.0
  alias camping_service service
  include Reststop::Base
  alias service reststop_service
  alias render reststop_render

	# Overrides the new Tilt-centric lookup method In camping
	# RESTstop needs to have a first try at looking up the view
	# located in the Views::HTML module. 
    def lookup(n)
      T.fetch(n.to_sym) do |k|
        t = CampingRestServices::Views::HTML.method_defined?(k) || camping_lookup(n)
      end
    end
end

module CampingRestServices::Models
  class Post < Base
    belongs_to :user
  end
  
  class Comment < Base; belongs_to :user; end
  class User < Base; end

  class BasicFields < V 1.0
    def self.up
      create_table :campingrestservices_posts, :force => true do |t|
        t.integer :user_id,          :null => false
        t.string  :title,            :limit => 255
        t.text    :body, :html_body
        t.timestamps
      end
      create_table :campingrestservices_users, :force => true do |t|
        t.string  :username, :password
      end
      create_table :campingrestservices_comments, :force => true do |t|
        t.integer :post_id,          :null => false
        t.string  :username
        t.text    :body, :html_body
        t.timestamps
      end
      User.create :username => 'admin', :password => 'camping'
    end

    def self.down
      drop_table :campingrestservices_posts
      drop_table :campingrestservices_users
      drop_table :campingrestservices_comments
    end
  end
  
end	

module CampingRestServices::Controllers
  extend Reststop::Controllers
  
    class Sessions < REST 'sessions'
        # POST /sessions
        def create
          @user = User.find_by_username_and_password(input.username, input.password)

          if @user
            @state.user_id = @user.id
            render :user
          else
			r(401, 'Wrong username or password.')
          end
        end   

        # DELETE /sessions
        def delete
          @state.user_id = nil
		  r(200, 'Session terminated')
        end
    end
  
    class Posts < REST 'posts'      
      # POST /posts
      def create
        require_login!
        @post = Post.create :title => (input.post_title || input.title),	
		  :body => (input.post_body || input.body),							
          :user_id => @state.user_id

		  redirect R(@post)	
      end

      # GET /posts/1
      # GET /posts/1.xml
      def read(post_id)
        @post = Post.find(post_id)

        render :view
      end

      # PUT /posts/1
      def update(post_id)
        require_login!
        @post = Post.find(post_id)
        @post.update_attributes :title => (input.post_title || input.title),	
			:body => (input.post_body || input.body)								

		redirect R(@post)
      end
	  
      # DELETE /posts/1
      def delete(post_id)
        require_login!
        @post = Post.find post_id

        if @post.destroy
          redirect R(Posts)
        else
          _error("Unable to delete post #{@post.id}", 500)
        end
      end
	  
      # GET /posts
      # GET /posts.xml
      def list
        @posts = Post.all(:order => 'updated_at DESC')
        render :index
      end
	  
      # GET /posts/new
      def new
        require_login!
		@user = User.find @state.user_id	
        @post = Post.new
        render :add
      end
	  
      # GET /posts/1/edit
      def edit(post_id)
        require_login!
 		@user = User.find @state.user_id	
        @post = Post.find(post_id)
        render :edit
      end
	  
	end

	# Utility controllers
	
    class Index
		def get
			redirect '/posts'
		end
	end
	
	class Login < R '/login'
		def get
			render :login
		end
	end

	class Logout < R '/logout'
		def get
			render :logout
		end
	end
	
end

module CampingRestServices::Helpers
  alias_method :_R, :R
  remove_method :R
  include Reststop::Helpers

  def logged_in?
    !!@state.user_id
  end

  def require_login!
    unless logged_in?
      redirect(R(CampingRestServices::Controllers::Login))	# @techarch: add explicit route
      throw :halt
    end
  end
end

module CampingRestServices::Views
  extend Reststop::Views
  
  module HTML
    include CampingRestServices::Controllers
    include CampingRestServices::Views
	
    def layout
      html do
        head do
          title 'My Blog'
          link :rel => 'stylesheet', :type => 'text/css', 
          :href => '/styles.css', :media => 'screen'
        end
        body do
          h1 { a 'My Blog', :href => R(Index) }
          
          div.wrapper! do
            text yield
          end
          
          hr
          
          p.footer! do
            if logged_in?
              _admin_menu
            else
              a 'Login', :href => R(Login)
              text ' to the adminpanel'
            end
            text ' &ndash; Powered by '
            a 'Camping', :href => 'http://camping.rubyforge.org/'
          end
        end
      end
    end

    def index
      if @posts.empty?
        h2 'No posts'
        p do
          text 'Could not find any posts. Feel free to '
          a 'add one', :href => R(Posts, 'new')
          text ' yourself. '
        end
      else
        @posts.each do |post|
          _post(post)
        end
      end
    end

    def login
      h2 'Login'
      p.info @info if @info
      
      form :action => R(Sessions), :method => 'post' do
        input :name => 'to', :type => 'hidden', :value => @to if @to
        
        label 'Username', :for => 'username'
        input :name => 'username', :id => 'username', :type => 'text'

        label 'Password', :for => 'password'
        input :name => 'password', :id => 'password', :type => 'password'

        input :type => 'submit', :class => 'submit', :value => 'Login'
      end
    end

	def user
      h2 "Welcome #{@user.username}!"
      a 'View Posts', :href => '/posts'
	end

    def logout
      h2 'Logout'
      
      form :action => R(Sessions), :method => 'delete' do
        input :type => 'submit', 
				:class => 'submit', 
				:value => 'Logout'
      end
    end
	
    def add
      _form(@post, :action => R(Posts))
    end

    def edit
      _form(@post, :action => R(@post), :method => :put) 
    end

    def view
      _post(@post)
    end

    # partials
    def _admin_menu
      text [['Log out', R(Logout)], ['New', R(Posts, 'new')]].map { |name, to|
        capture { a name, :href => to}
      }.join(' &ndash; ')
    end

    def _post(post)
      h2 { a post.title, :href => R(Posts, post.id) }
	  p { post.body }
	  
      p.info do
        text "Written by <strong>#{post.user.username}</strong> "
        text post.updated_at.strftime('%B %M, %Y @ %H:%M ')
        _post_menu(post)
      end
      text post.html_body
    end
    
    def _post_menu(post)
      if logged_in?
        a '(edit)', 	 :href => R(Posts, post.id,'edit')
		span '|'
        a '(delete)', :href => R(Posts, post.id, 'delete')		
      end
    end

    def _form(post, opts)
      form({:method => 'post'}.merge(opts)) do
        label 'Title:', :for => 'post_title'
        input :name => 'post_title', :id => 'post_title', :type => 'text', 
              :value => post.title
		br
		
        label 'Body:', :for => 'post_body'
        textarea post.body, :name => 'post_body', :id => 'post_body'
		br
		
        input :type => 'hidden', :name => 'post_id', :value => post.id
        input :type => 'submit', :class => 'submit', :value => 'Submit'
      end
    end
  end #HTML
  
  module XML
    def layout
      yield
    end

	def user
		@user.to_xml(:root => 'user')
	end
	
    def index
      @posts.to_xml(:root => 'blog')
    end

    def view
      @post.to_xml(:root => 'post')
    end
  end #XML
    
  module JSON
    def layout
      yield
    end

	def user
		@user.to_json
	end
	
    def index
      @posts.to_json
    end

    def view
      @post.to_json
    end
  end #JSON
  
  default_format :HTML
  
end #Views

CampingRestServices.create
