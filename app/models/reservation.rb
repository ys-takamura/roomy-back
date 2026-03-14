class Reservation < ApplicationRecord
  belongs_to :room
  belongs_to :user

  has_many :reservation_participants, dependent: :destroy
  has_many :participants, through: :reservation_participants, source: :user

  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :title, presence: true
  validate :end_time_after_start_time
  validate :no_room_time_overlap
  validate :no_participant_time_overlap

  private

  # 終了時刻が開始時刻より後であることを検証する
  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?
    return if end_time > start_time

    errors.add(:end_time, "は開始時刻より後にしてください")
  end

  # 同じ部屋で時間が被っている予約がないか検証する
  def no_room_time_overlap
    return if start_time.blank? || end_time.blank? || room_id.blank?

    overlapping = room.reservations.where.not(id: id).where(
      "start_time < ? AND end_time > ?",
      end_time,
      start_time
    ).exists?

    return unless overlapping

    errors.add(:base, "この部屋は指定された時間に既に予約が入っています")
  end

  # 作成者・参加者のいずれかが、同じ時間に別の予約（他室含む）に入っていないか検証する
  def no_participant_time_overlap
    return if start_time.blank? || end_time.blank?

    user_ids_to_check = involved_user_ids
    return if user_ids_to_check.empty?

    base = Reservation
      .where.not(id: id)
      .where("start_time < ? AND end_time > ?", end_time, start_time)

    # .or() は joins の有無が異なる Relation 同士では使えないため、別々に exists? で判定する
    creator_overlap = base.where(user_id: user_ids_to_check).exists?
    participant_overlap = base.joins(:reservation_participants).where(reservation_participants: { user_id: user_ids_to_check }).exists?

    return unless creator_overlap || participant_overlap

    errors.add(:base, "参加者のいずれかが指定された時間に別の予約が入っています")
  end

  # この予約に関わるユーザーID（作成者 + 参加者）を返す
  def involved_user_ids
    ids = [user_id].compact
    ids.concat(reservation_participants.map(&:user_id)) if reservation_participants.loaded? || reservation_participants.any?
    ids.uniq
  end
end

