use axum::{
    extract::{State, Json},
    http::StatusCode,
};
use crate::models::{AppState, AdminApprovalRequest};

pub async fn principal_approve_hod_handler(
    State(state): State<AppState>,
    Json(payload): Json<AdminApprovalRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::management::principal_service::principal_approve_hod(&state.pool, payload).await {
        Ok(res) => {
            println!("PRINCIPAL Approve HOD Result: {:?}", res);
            Ok(Json(serde_json::json!({
                "success": true,
                "message": "HOD approved successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("PRINCIPAL Approve HOD Error: {:?}", e);
            Err((e, Json(serde_json::json!({
                "success": false,
                "message": "Failed to approve HOD",
                "data": null
            }))))
        },
    }
}
