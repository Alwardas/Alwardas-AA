use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
use crate::models::{AppState, AdminUserQuery, AdminUserDTO, AdminStats, AdminApprovalRequest};

pub async fn get_admin_users_handler(
    State(state): State<AppState>,
    Query(params): Query<AdminUserQuery>,
) -> Result<Json<Vec<AdminUserDTO>>, StatusCode> {
    match crate::services::management::admin_service::get_admin_users(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_admin_stats_handler(
    State(state): State<AppState>,
) -> Result<Json<AdminStats>, StatusCode> {
    match crate::services::management::admin_service::get_admin_stats(&state.pool).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn admin_approve_user_handler(
    State(state): State<AppState>,
    Json(payload): Json<AdminApprovalRequest>,
) -> Result<StatusCode, StatusCode> {
    match crate::services::management::admin_service::admin_approve_user(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err(e),
    }
}
