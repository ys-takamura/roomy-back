class Api::V1::ReservationsController < ApplicationController
  before_action :authenticate_user_with_jwt!
  before_action :set_company
  before_action :set_room, only: %i[show create update destroy]
  before_action :set_reservation, only: %i[show update destroy]

  # GET /api/v1/reservations?from=...&to=... 会社の予約を日付範囲で取得
  def index
    scope = Reservation.joins(room: :company).where(companies: { id: @current_user.company_id })

    if params[:from].present? && params[:to].present?
      from = Time.zone.parse(params[:from])
      to = Time.zone.parse(params[:to])
      scope = scope.where("start_time < ? AND end_time > ?", to, from)
    end

    reservations = scope.includes(:room, :user, :reservation_participants).order(:start_time)
    render json: reservations.map { |r| reservation_json(r) }
  end

  def show
    render json: reservation_json(@reservation)
  end

  def create
    reservation = @room.reservations.new(reservation_params.merge(user: @current_user))

    # 参加者（作成者 + 指定されたメンバー）を事前に組み立て（バリデーションで重複チェックするため）
    participant_ids_raw = params.dig(:reservation, :participant_ids)
    participant_user_ids = (Array(participant_ids_raw).reject(&:blank?).map(&:to_i).reject(&:zero?) + [@current_user.id]).uniq
    participant_user_ids.each do |user_id|
      user = @company.users.find_by(id: user_id)
      reservation.reservation_participants.build(user: user) if user
    end

    if reservation.save
      render json: reservation_json(reservation), status: :created
    else
      render json: { errors: reservation.errors.full_messages }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error([e.message, e.backtrace].join("\n"))
    render json: { error: e.message, backtrace: (e.backtrace.first(5) if Rails.env.development?) }, status: :internal_server_error
  end

  def update
    unless @reservation.user_id == @current_user.id || @current_user.admin?
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    @reservation.assign_attributes(reservation_params)

    # 参加者を差し替え（作成者 + 指定メンバー）
    participant_ids_raw = params.dig(:reservation, :participant_ids)
    participant_user_ids = (Array(participant_ids_raw).reject(&:blank?).map(&:to_i).reject(&:zero?) + [@reservation.user_id]).uniq
    @reservation.reservation_participants.destroy_all
    participant_user_ids.each do |user_id|
      user = @company.users.find_by(id: user_id)
      @reservation.reservation_participants.build(user: user) if user
    end

    if @reservation.save
      render json: reservation_json(@reservation)
    else
      render json: { errors: @reservation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    # 自分の予約か管理者のみ削除可能
    unless @reservation.user_id == @current_user.id || @current_user.admin?
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    @reservation.destroy!
    head :no_content
  end

  private

  def set_company
    @company = @current_user.company
  end

  def set_room
    @room = @company.rooms.find(params[:room_id])
  end

  def set_reservation
    @reservation = @room.reservations.includes(:room, :user, :reservation_participants).find(params[:id])
  end

  def reservation_params
    params.require(:reservation).permit(:start_time, :end_time, :title, :remarks)
  end

  def reservation_json(reservation)
    reservation.as_json(include: { room: { only: %i[id name] }, user: { only: %i[id name] } }).merge(
      "participant_ids" => reservation.reservation_participants.map(&:user_id)
    )
  end
end

