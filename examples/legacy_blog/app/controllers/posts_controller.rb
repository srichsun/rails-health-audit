# Intentionally bad legacy code — used to demonstrate rails-health-audit.
# Do not copy any of this. Every "smell" here is on purpose.
class PostsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    # SQL injection: raw interpolation of user input
    @posts = Post.where("title LIKE '%#{params[:q]}%'").order(params[:sort])
    @count = Post.connection.execute("SELECT COUNT(*) FROM posts WHERE title LIKE '%#{params[:q]}%'")
  end

  def create
    # Mass assignment: whole params hash, no strong params
    @post = Post.new(params[:post])

    # A long, do-everything method (high complexity, many statements)
    if @post.save
      logger.info "created #{@post.id}"
      @post.user.notify if @post.user
      tags = params[:tags].to_s.split(",")
      tags.each do |t|
        @post.tags.create(name: t.strip) unless t.strip.empty?
      end
      thumb = params[:thumb]
      # Command injection: shelling out with user input
      system("convert #{thumb} -resize 100x100 #{Rails.root}/public/thumbs/#{@post.id}.png")
      flash[:notice] = "created"
      redirect_to posts_path
    else
      flash[:error] = "failed"
      render :new
    end
  rescue Exception => e   # rescuing Exception swallows everything
    logger.error e.message
    render :new
  end

  # Duplicated logic — near-identical to #create on purpose (flay catches this)
  def update
    @post = Post.find(params[:id])
    if @post.update_attributes(params[:post])
      logger.info "updated #{@post.id}"
      @post.user.notify if @post.user
      tags = params[:tags].to_s.split(",")
      tags.each do |t|
        @post.tags.create(name: t.strip) unless t.strip.empty?
      end
      flash[:notice] = "updated"
      redirect_to posts_path
    else
      flash[:error] = "failed"
      render :edit
    end
  end
end
