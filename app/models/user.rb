class User < ApplicationRecord
  belongs_to :company

  # 権限
  enum :role, {
    admin: 0, # 管理者
    staff: 1  # 一般ユーザー
  }

  # パスワードのハッシュ化
  has_secure_password

  # 作成した予約
  has_many :reservations, dependent: :destroy

  # 参加している予約
  has_many :reservation_participants, dependent: :destroy
  has_many :participating_reservations, through: :reservation_participants, source: :reservation

  # バリデーション（パスワードは新規作成時のみ必須、編集時は入力時のみ変更）
  validates :name,  presence: true
  validates :email, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 8 }, on: :create
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  # 管理者が 0 人にならないようにする
  before_update :ensure_company_has_at_least_one_admin_on_update
  before_destroy :ensure_company_has_at_least_one_admin_on_destroy

  private

  def other_admins_count
    company.users.where(role: :admin).where.not(id: id).count
  end

  def ensure_company_has_at_least_one_admin_on_update
    # 管理者→一般への変更時のみチェック（role_was は DB から読んだ変更前の値）
    return unless role_was == "admin" && role != "admin"
    return if other_admins_count >= 1

    errors.add(:base, "会社には最低1人の管理者が必要です")
    throw :abort
  end

  def ensure_company_has_at_least_one_admin_on_destroy
    # 削除時は role がまだ「admin」のままなので、自分が管理者かだけ見る
    return unless role == "admin"
    return if other_admins_count >= 1

    errors.add(:base, "会社には最低1人の管理者が必要です")
    throw :abort
  end
end
