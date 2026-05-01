use sqlx::{PgPool};
use axum::http::StatusCode;
use crate::models::{AdminUserQuery, AdminUserDTO, AdminStats, AdminApprovalRequest};
use crate::repositories::management::admin_repository;

pub async fn get_admin_users(pool: &PgPool, params: AdminUserQuery) -> Result<Vec<AdminUserDTO>, StatusCode> {
    admin_repository::find_users(pool, params)
        .await
        .map_err(|e| {
            eprintln!("Admin Users Fetch Error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })
}

pub async fn get_admin_stats(pool: &PgPool) -> Result<AdminStats, StatusCode> {
    admin_repository::get_admin_stats(pool)
        .await
        .map_err(|e| {
            eprintln!("Admin Stats Error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })
}

pub async fn admin_approve_user(pool: &PgPool, payload: AdminApprovalRequest) -> Result<(), StatusCode> {
    if payload.action == "APPROVE" {
        admin_repository::approve_user(pool, payload.user_id)
            .await
            .map(|_| ())
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    } else if payload.action == "REJECT" || payload.action == "DELETE" {
        admin_repository::delete_user(pool, payload.user_id)
            .await
            .map(|_| ())
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    }
    Ok(())
}
