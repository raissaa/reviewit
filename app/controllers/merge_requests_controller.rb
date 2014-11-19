class MergeRequestsController < ApplicationController
  before_action :authenticate_user!

  def update
    @patch = merge_request.patches.find_by_id(params[:patch_id]) or raise 'Invalid patch'
    MergeRequest.transaction do
      create_comments params[:comments]
    end

    case params[:mr_action]
    when 'Accept' then accept
    when 'Abandon' then abandon
    else
      redirect_to action: :show
    end
  end

  def index
    @mrs = merge_requests.pending.paginate(page: params[:page])
  end

  def old_ones
    @mrs = merge_requests.closed.paginate(page: params[:page])
  end

  def history
    @mr = project.merge_requests.includes(history_events: [:who]).find(params[:id])
  end

  def show
    @version = params[:version].to_i
    raise ActiveRecord::RecordNotFound.new if @version < 0

    @patch = merge_request.patches[@version - 1] or raise ActiveRecord::RecordNotFound.new
    @version = merge_request.patches.count if @version.zero?
  end

  private

  def merge_requests
    project.merge_requests.includes(:author, :patches).order(updated_at: :desc)
  end

  def accept
    @mr.integrate! current_user
    redirect_to action: :index
  end

  def abandon
    @mr.abandon! current_user
    redirect_to action: :index
  end

  def create_comments comments
    return if comments.nil?

    comments.each do |location, text|
      next if text.strip.empty?
      comment = Comment.new
      comment.user = current_user
      comment.patch = @patch
      comment.content = text
      comment.location = location
      comment.save!
    end
  end
end
