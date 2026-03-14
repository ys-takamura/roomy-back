class Api::V1::SessionsController < ApplicationController
  def create
    user = User.find_by(email: session_params[:email])

    if user&.authenticate(session_params[:password])
      token = encode_token({ user_id: user.id })
      user_json = user.as_json.merge("company_name" => user.company.name)
      render json: { token: token, user: user_json }, status: :ok
    else
      render json: { error: "メールアドレスまたはパスワードが正しくありません" }, status: :unauthorized
    end
  end

  # JWT はサーバー側で状態を持たないので、
  # クライアント側でトークンを破棄してもらう前提の「論理ログアウト」エンドポイント
  def destroy
    head :no_content
  end

  private

  def session_params
    params.require(:session).permit(:email, :password)
  end
end

