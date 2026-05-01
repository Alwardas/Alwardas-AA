use axum::{
    extract::{State, Json},
    http::StatusCode,
};
use crate::models::{AppState, AdminApprovalRequest};

pub async fn principal_approve_hod_handler(
    State(state): State<AppState>,
    Json(payload): Json<AdminApprovalRequest>,
) -> Result<StatusCode, StatusCode> {
    match crate::services::management::principal_service::principal_approve_hod(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err(e),
    }
}
