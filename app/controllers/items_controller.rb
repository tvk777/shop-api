class ItemsController < ApplicationController
  def index
    items = Item.order(:name)

    if params[:q].present?
      term = "%#{Item.sanitize_sql_like(params[:q])}%"
      items = items.where("name ILIKE :term OR description ILIKE :term", term: term)
    end

    render json: items.as_json(only: [:id, :name, :description, :price])
  end
end