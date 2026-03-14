class Api::V1::UsersController < ApplicationController
  before_action :authenticate_user_with_jwt!
  before_action :set_company
  before_action :set_user, only: %i[show update destroy]

  def index
    render json: @company.users
  end

  def show
    render json: @user
  end

  def create
    user = @company.users.new(user_params)

    if user.save
      render json: user, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    attrs = user_params.to_h
    # 自分自身の更新時は権限(role)を変更できない
    attrs.except!(:role) if @user.id == @current_user.id
    attrs.except!(:password, :password_confirmation) if attrs[:password].blank?
    if @user.update(attrs)
      render json: @user
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy!
    head :no_content
  end

  private

  def set_company
    @company = @current_user.company
  end

  def set_user
    @user = @company.users.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :role, :password, :password_confirmation)
  end
end