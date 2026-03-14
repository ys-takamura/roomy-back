# ログイン中のユーザーの会社情報の取得・更新（設定用）
class Api::V1::CompaniesController < ApplicationController
  before_action :authenticate_user_with_jwt!

  def show
    render json: @current_user.company
  end

  def update
    unless @current_user.admin?
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    if @current_user.company.update(company_params)
      render json: @current_user.company
    else
      render json: { errors: @current_user.company.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def company_params
    params.require(:company).permit(:name)
  end
end
