class ItemsController < ApplicationController
  def index
    render json: Item.search(search_param).order(:name)
  end
end
