class ItemsController < ApplicationController
  def index
    items, meta = paginate(Item.search(search_param).order(:name, :id), default_per_page: 12)
    render json: { data: items, meta: meta }
  end
end
