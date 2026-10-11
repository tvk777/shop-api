class ItemsController < ApplicationController
  def index
    render json: Item.search(params[:q]).order(:name)
  end
end
