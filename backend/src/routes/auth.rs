use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
use crate::models::*;

// --- Auth Handlers ---

pub async fn signup_handler(
    State(state): State<AppState>,
    Json(payload): Json<SignupRequest>,
) -> Result<Json<AuthResponse>, (StatusCode, Json<AuthResponse>)> {
    match crate::services::auth_service::signup_user(&state.pool, payload).await {
        Ok(resp) => Ok(Json(resp)),
        Err(e) => Err(e),
    }
}

pub async fn reject_my_pending_update_handler(
    State(state): State<AppState>,
    Json(payload): Json<serde_json::Value>, 
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    crate::services::auth_service::reject_my_pending_update(&state.pool, payload).await
}

pub async fn check_my_pending_update_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>, 
) -> Result<Json<serde_json::Value>, StatusCode> {
    match crate::services::auth_service::check_my_pending_update(&state.pool, params).await {
        Ok(resp) => Ok(Json(resp)),
        Err(e) => Err(e),
    }
}

pub async fn accept_my_pending_update_handler(
    State(state): State<AppState>,
    Json(payload): Json<serde_json::Value>, 
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    crate::services::auth_service::accept_my_pending_update(&state.pool, payload).await
}

pub async fn login_handler(
    State(state): State<AppState>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<AuthResponse>, (StatusCode, Json<AuthResponse>)> {
    match crate::services::auth_service::login_user(&state.pool, payload).await {
        Ok(resp) => Ok(Json(resp)),
        Err(e) => Err(e),
    }
}

pub async fn check_user_existence_handler(
    State(state): State<AppState>,
    Query(params): Query<CheckUserQuery>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    match crate::services::auth_service::check_user_existence(&state.pool, params).await {
        Ok(resp) => Ok(Json(resp)),
        Err(e) => Err(e),
    }
}

pub async fn forgot_password_handler(
    State(state): State<AppState>,
    Json(payload): Json<ForgotPasswordRequest>,
) -> Result<Json<ResetResponse>, (StatusCode, Json<ResetResponse>)> {
    match crate::services::auth_service::forgot_password(&state.pool, payload).await {
        Ok(resp) => Ok(Json(resp)),
        Err(e) => Err(e),
    }
}

pub async fn change_password_handler(
    State(state): State<AppState>,
    Json(payload): Json<ChangePasswordRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    crate::services::auth_service::change_password(&state.pool, payload).await
}

pub async fn update_user_handler(
    State(state): State<AppState>,
    Json(payload): Json<UpdateUserRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    crate::services::auth_service::update_user(&state.pool, payload).await
}

pub async fn get_notifications_handler(
    State(state): State<AppState>,
    Query(params): Query<NotificationQuery>,
) -> Result<Json<Vec<Notification>>, StatusCode> {
    match crate::services::notification_service::get_notifications(&state.pool, params).await {
        Ok(notifications) => Ok(Json(notifications)),
        Err(e) => Err(e),
    }
}

pub async fn delete_notifications_handler(
    State(state): State<AppState>,
    Json(payload): Json<DeleteNotificationsRequest>,
) -> Result<StatusCode, StatusCode> {
    crate::services::notification_service::delete_notifications(&state.pool, payload.ids).await?;
    Ok(StatusCode::OK)
}

