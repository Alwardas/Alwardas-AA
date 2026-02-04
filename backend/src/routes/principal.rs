use axum::{
    extract::{State, Json},
    http::StatusCode,
};
use sqlx;
use crate::models::{AppState, AdminApprovalRequest};

pub async fn principal_approve_hod_handler(
    State(state): State<AppState>,
    Json(payload): Json<AdminApprovalRequest>,
) -> Result<StatusCode, StatusCode> {
    // Reuse the same logic as admin approval for now, or add specific HOD logic if needed
    if payload.action == "APPROVE" {
        sqlx::query("UPDATE users SET is_approved = TRUE WHERE id = $1 AND role = 'HOD'")
            .bind(payload.user_id)
            .execute(&state.pool)
            .await
            .map_err(|e| {
                eprintln!("Principal Approve HOD Error: {:?}", e);
                StatusCode::INTERNAL_SERVER_ERROR
            })?;
    } else if payload.action == "REJECT" || payload.action == "DELETE" {
         sqlx::query("DELETE FROM users WHERE id = $1 AND role = 'HOD'")
            .bind(payload.user_id)
            .execute(&state.pool)
            .await
            .map_err(|e| {
                eprintln!("Principal Reject HOD Error: {:?}", e);
                StatusCode::INTERNAL_SERVER_ERROR
            })?;
    }
    Ok(StatusCode::OK)
}
