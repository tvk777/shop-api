class ItemsController < ApplicationController
  def index
    render json: Item.search(params[:q]).order(:name).as_json(only: [ :id, :name, :description, :price ])
  end
end
