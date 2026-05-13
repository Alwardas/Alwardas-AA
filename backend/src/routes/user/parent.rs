use axum::{
    extract::{State, Query, Path},
    Json,
    http::StatusCode,
};
use crate::models::{AppState, ProfileQuery, ParentProfileResponse, ParentRequest, ParentRequestQuery, SubmitParentRequest, UpdateParentRequestStatus};
use uuid::Uuid;

pub async fn get_parent_profile_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::parent_service::get_parent_profile(&state.pool, &params.user_id).await {
        Ok(res) => {
            println!("GET Parent Profile Result: {:?}", res);
            Ok(Json(serde_json::json!({
                "success": true,
                "message": "Parent profile fetched",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Parent Profile Error: {:?}", e);
            Err((e, Json(serde_json::json!({
                "success": false,
                "message": "Failed to fetch profile",
                "data": null
            }))))
        },
    }
}

pub async fn submit_parent_request_handler(
    State(state): State<AppState>,
    Json(payload): Json<SubmitParentRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::parent_service::submit_parent_request(&state.pool, payload).await {
        Ok(res) => {
            println!("SUBMIT Parent Request Result: {:?}", res);
            Ok(Json(serde_json::json!({
                "success": true,
                "message": "Request submitted successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("SUBMIT Parent Request Error: {:?}", e);
            Err((e, Json(serde_json::json!({
                "success": false,
                "message": "Failed to submit request",
                "data": null
            }))))
        },
    }
}

pub async fn get_parent_requests_handler(
    State(state): State<AppState>,
    Query(params): Query<ParentRequestQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::parent_service::get_parent_requests(&state.pool, params).await {
        Ok(res) => {
            println!("GET Parent Requests Result: {:?}", res);
            Ok(Json(serde_json::json!({
                "success": true,
                "message": "Requests fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Parent Requests Error: {:?}", e);
            Err((e, Json(serde_json::json!({
                "success": false,
                "message": "Failed to fetch requests",
                "data": null
            }))))
        },
    }
}

pub async fn update_parent_request_status_handler(
    State(state): State<AppState>,
    Path(request_id): Path<Uuid>,
    Json(payload): Json<UpdateParentRequestStatus>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::parent_service::update_parent_request_status(&state.pool, request_id, payload.status).await {
        Ok(res) => {
            println!("UPDATE Parent Request Result: {:?}", res);
            Ok(Json(serde_json::json!({
                "success": true,
                "message": "Status updated successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("UPDATE Parent Request Error: {:?}", e);
            Err((e, Json(serde_json::json!({
                "success": false,
                "message": "Failed to update status",
                "data": null
            }))))
        },
    }
}

pub async fn delete_parent_request_handler(
    State(state): State<AppState>,
    Path(request_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::parent_service::delete_parent_request(&state.pool, request_id).await {
        Ok(res) => {
            println!("DELETE Parent Request Result: {:?}", res);
            Ok(Json(serde_json::json!({
                "success": true,
                "message": "Request deleted successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("DELETE Parent Request Error: {:?}", e);
            Err((e, Json(serde_json::json!({
                "success": false,
                "message": "Failed to delete request",
                "data": null
            }))))
        },
    }
}
