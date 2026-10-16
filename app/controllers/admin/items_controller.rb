class Admin::ItemsController < Admin::BaseController
  def index
    items, meta = paginate(Item.search(search_param).order(:name, :id), default_per_page: 20)
    render json: { data: items, meta: meta }
  end

  def show
    render json: Item.find(params[:id])
  end

  def create
    item = Item.new(item_params)

    if item.save
      render json: item, status: :created
    else
      render_errors(item)
    end
  end

  def update
    item = Item.find(params[:id])

    if item.update(item_params)
      render json: item
    else
      render_errors(item)
    end
  end

  def destroy
    item = Item.find(params[:id])

    if item.destroy
      head :no_content
    else
      render_errors(item)
    end
  end

  private

  def item_params
    params.expect(item: [ :name, :description, :price ])
  end
end
