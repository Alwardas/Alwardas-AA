use sqlx::PgPool;
use axum::http::StatusCode;
use crate::models::AdminApprovalRequest;
use crate::repositories::management::principal_repository;

pub async fn principal_approve_hod(pool: &PgPool, payload: AdminApprovalRequest) -> Result<(), StatusCode> {
    if payload.action == "APPROVE" {
        principal_repository::approve_hod(pool, payload.user_id)
            .await
            .map(|_| ())
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    } else if payload.action == "REJECT" || payload.action == "DELETE" {
        principal_repository::delete_hod(pool, payload.user_id)
            .await
            .map(|_| ())
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    }
    Ok(())
}
