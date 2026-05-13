use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
use crate::models::{AppState, AdminUserQuery, AdminApprovalRequest};

pub async fn get_admin_users_handler(
    State(state): State<AppState>,
    Query(params): Query<AdminUserQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::management::admin_service::get_admin_users(&state.pool, params).await {
        Ok(res) => {
            println!("GET Admin Users Result: {:?}", res);
            Ok(Json(serde_json::json!({
                "success": true,
                "message": "Users fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Admin Users Error: {:?}", e);
            Err((e, Json(serde_json::json!({
                "success": false,
                "message": "Failed to fetch users",
                "data": null
            }))))
        },
    }
}

pub async fn get_admin_stats_handler(
    State(state): State<AppState>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::management::admin_service::get_admin_stats(&state.pool).await {
        Ok(res) => {
            println!("GET Admin Stats Result: {:?}", res);
            Ok(Json(serde_json::json!({
                "success": true,
                "message": "Stats fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Admin Stats Error: {:?}", e);
            Err((e, Json(serde_json::json!({
                "success": false,
                "message": "Failed to fetch stats",
                "data": null
            }))))
        },
    }
}

pub async fn admin_approve_user_handler(
    State(state): State<AppState>,
    Json(payload): Json<AdminApprovalRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::management::admin_service::admin_approve_user(&state.pool, payload).await {
        Ok(res) => {
            println!("ADMIN Approve User Result: {:?}", res);
            Ok(Json(serde_json::json!({
                "success": true,
                "message": "User approved successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("ADMIN Approve User Error: {:?}", e);
            Err((e, Json(serde_json::json!({
                "success": false,
                "message": "Failed to approve user",
                "data": null
            }))))
        },
    }
}
