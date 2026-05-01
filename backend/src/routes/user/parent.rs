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
) -> Result<Json<ParentProfileResponse>, StatusCode> {
    match crate::services::user::parent_service::get_parent_profile(&state.pool, &params.user_id).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn submit_parent_request_handler(
    State(state): State<AppState>,
    Json(payload): Json<SubmitParentRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::parent_service::submit_parent_request(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err((e, Json(serde_json::json!({"error": "Failed to submit request"})))),
    }
}

pub async fn get_parent_requests_handler(
    State(state): State<AppState>,
    Query(params): Query<ParentRequestQuery>,
) -> Result<Json<Vec<ParentRequest>>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::parent_service::get_parent_requests(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err((e, Json(serde_json::json!({"error": "Failed to fetch requests"})))),
    }
}

pub async fn update_parent_request_status_handler(
    State(state): State<AppState>,
    Path(request_id): Path<Uuid>,
    Json(payload): Json<UpdateParentRequestStatus>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::parent_service::update_parent_request_status(&state.pool, request_id, payload.status).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err((e, Json(serde_json::json!({"error": "Failed to update status"})))),
    }
}

pub async fn delete_parent_request_handler(
    State(state): State<AppState>,
    Path(request_id): Path<Uuid>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::parent_service::delete_parent_request(&state.pool, request_id).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err((e, Json(serde_json::json!({"error": "Failed to delete request"})))),
    }
}
