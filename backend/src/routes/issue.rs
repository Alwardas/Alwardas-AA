use axum::{
    extract::{State, Query, Path},
    Json,
    http::StatusCode,
};
use crate::models::*;
use uuid::Uuid;

pub async fn submit_issue_handler(
    State(state): State<AppState>,
    Json(payload): Json<SubmitIssueRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::issue_service::submit_issue(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}

pub async fn get_issues_handler(
    State(state): State<AppState>,
    Query(params): Query<GetIssuesQuery>,
) -> Result<Json<Vec<Issue>>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::issue_service::get_issues(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}

pub async fn get_issue_details_handler(
    State(state): State<AppState>,
    Path(issue_id): Path<Uuid>,
) -> Result<Json<Issue>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::issue_service::get_issue_details(&state.pool, issue_id).await {
        Ok(res) => Ok(Json(res)),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}

pub async fn get_issue_comments_handler(
    State(state): State<AppState>,
    Path(issue_id): Path<Uuid>,
) -> Result<Json<Vec<IssueComment>>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::issue_service::get_issue_comments(&state.pool, issue_id).await {
        Ok(res) => Ok(Json(res)),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}

pub async fn submit_comment_handler(
    State(state): State<AppState>,
    Json(payload): Json<SubmitCommentRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::issue_service::submit_comment(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}

pub async fn assign_issue_handler(
    State(state): State<AppState>,
    Path(issue_id): Path<Uuid>,
    Json(payload): Json<AssignIssueRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::issue_service::assign_issue(&state.pool, issue_id, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}

pub async fn update_issue_status_handler(
    State(state): State<AppState>,
    Path(issue_id): Path<Uuid>,
    Json(payload): Json<UpdateIssueStatusRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::issue_service::update_issue_status(&state.pool, issue_id, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}

pub async fn delete_issue_handler(
    State(state): State<AppState>,
    Path(issue_id): Path<Uuid>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::issue_service::delete_issue(&state.pool, issue_id).await {
        Ok(_) => Ok(StatusCode::OK),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}
