# Intentionally insecure controller — used to demonstrate rails-health-audit.
# Do NOT copy any of this. Every smell here is on purpose.
class ProductsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    # SQL injection: raw interpolation of user input
    @products = Product.where("name LIKE '%#{params[:q]}%'").order(params[:sort])
    @count = Product.connection.execute(
      "SELECT COUNT(*) FROM products WHERE name LIKE '%#{params[:q]}%'"
    )
  end

  def create
    # Mass assignment: whole params hash, no strong params
    @product = Product.new(params[:product])

    # A long do-everything method (high complexity, many statements)
    if @product.save
      logger.info "created #{@product.id}"
      @product.notify_owner if @product.owner
      tags = params[:tags].to_s.split(",")
      tags.each do |t|
        @product.tags.create(name: t.strip) unless t.strip.empty?
      end
      thumb = params[:thumb]
      # Command injection: shelling out with user input
      system("convert #{thumb} -resize 100x100 #{Rails.root}/public/thumbs/#{@product.id}.png")
      flash[:notice] = "created"
      redirect_to products_path
    else
      flash[:error] = "failed"
      render :new
    end
  rescue Exception => e # rescuing Exception swallows everything
    logger.error e.message
    render :new
  end

  # Duplicated logic — near-identical to #create on purpose (flay catches this)
  def update
    @product = Product.find(params[:id])
    if @product.update_attributes(params[:product])
      logger.info "updated #{@product.id}"
      @product.notify_owner if @product.owner
      tags = params[:tags].to_s.split(",")
      tags.each do |t|
        @product.tags.create(name: t.strip) unless t.strip.empty?
      end
      flash[:notice] = "updated"
      redirect_to products_path
    else
      flash[:error] = "failed"
      render :edit
    end
  end
end
