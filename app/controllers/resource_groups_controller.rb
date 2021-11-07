class ResourceGroupsController < ApplicationController

  before_action :set_rg, only: %i[show update destroy]
  def index
    @resource_groups = @current_user.resource_groups
    respond_to do |format|
      format.html
      format.json { render @resource_groups.as_json }
    end
  end

  def show
    respond_to do |format|
      format.html { redirect_to resource_groups_path }
      format.json { render @resource_group.as_json }
    end
  end

  def update
    @resource_group.update(name: update_params[:name],
                           accounts: update_params[:accounts],
                           default: update_params[:default])
    respond_to do |format|
      format.html { redirect_to resource_groups_path }
      format.json { render @resource_group.as_json }
    end
  end

  def destroy
    @resource_group.destroy
    respond_to do |format|
      format.html { redirect_to resource_groups_path }
      format.json { render status: :no_content }
    end
  end

  private

  def set_rg
    @resource_group = ResourceGroup.find(params[:id])
  end

  def update_params
    params.require(:resource_group).permit(:id, :name, :accounts, :default)
  end
end
