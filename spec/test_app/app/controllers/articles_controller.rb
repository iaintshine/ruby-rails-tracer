class ArticlesController < ApplicationController
  def index
    render json: Article.all
  end
end
