use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
    response::IntoResponse,
};
use uuid::Uuid;
use crate::models::{AppState, CreateAnnouncementRequest, GetAnnouncementsQuery};
use serde_json::json;

pub async fn create_announcement_handler(
    State(state): State<AppState>,
    Json(body): Json<CreateAnnouncementRequest>,
) -> impl IntoResponse {
    match crate::services::management::coordinator_service::create_announcement(&state.pool, body).await {
        Ok(announcement) => (StatusCode::CREATED, Json(json!({"message": "Announcement created successfully", "announcement": announcement}))).into_response(),
        Err((c, msg)) => (c, Json(json!({"message": msg}))).into_response(),
    }
}

pub async fn get_announcements_handler(
    State(state): State<AppState>,
    Query(params): Query<GetAnnouncementsQuery>,
) -> impl IntoResponse {
    match crate::services::management::coordinator_service::get_announcements(&state.pool, params).await {
        Ok(announcements) => (StatusCode::OK, Json(announcements)).into_response(),
        Err(_) => (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": "Failed to fetch announcements"}))).into_response(),
    }
}

pub async fn get_all_departments_handler(
    State(state): State<AppState>,
) -> impl IntoResponse {
    match crate::services::management::coordinator_service::get_all_departments(&state.pool).await {
        Ok(departments) => (StatusCode::OK, Json(departments)).into_response(),
        Err(_) => (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": "Failed to fetch departments"}))).into_response(),
    }
}

pub async fn delete_department_handler(
    State(state): State<AppState>,
    Json(payload): Json<serde_json::Value>,
) -> impl IntoResponse {
    let branch = payload.get("branch").and_then(|v| v.as_str());
    if let Some(branch_name) = branch {
        match crate::services::management::coordinator_service::delete_department(&state.pool, branch_name).await {
            Ok(affected) if affected > 0 => (StatusCode::OK, Json(json!({"message": "Department deleted successfully"}))).into_response(),
            Ok(_) => (StatusCode::NOT_FOUND, Json(json!({"message": "Department not found"}))).into_response(),
            Err(_) => (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": "Failed to delete department"}))).into_response(),
        }
    } else {
        (StatusCode::BAD_REQUEST, Json(json!({"message": "Branch name is required"}))).into_response()
    }
}

pub async fn delete_announcement_handler(
    State(state): State<AppState>,
    Json(payload): Json<serde_json::Value>,
) -> impl IntoResponse {
    let id_str = payload.get("id").and_then(|v| v.as_str());
    if let Some(id_str) = id_str {
        if let Ok(announcement_id) = Uuid::parse_str(id_str) {
            match crate::services::management::coordinator_service::delete_announcement(&state.pool, announcement_id).await {
                Ok(affected) if affected > 0 => (StatusCode::OK, Json(json!({"message": "Announcement deleted successfully"}))).into_response(),
                Ok(_) => (StatusCode::NOT_FOUND, Json(json!({"message": "Announcement not found"}))).into_response(),
                Err(_) => (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": "Failed to delete announcement"}))).into_response(),
            }
        } else {
            (StatusCode::BAD_REQUEST, Json(json!({"message": "Invalid announcement ID format"}))).into_response()
        }
    } else {
        (StatusCode::BAD_REQUEST, Json(json!({"message": "Announcement ID is required"}))).into_response()
    }
}

pub async fn pin_announcement_handler(
    State(state): State<AppState>,
    Json(payload): Json<serde_json::Value>,
) -> impl IntoResponse {
    let id_str = payload.get("id").and_then(|v| v.as_str());
    let is_pinned = payload.get("isPinned").and_then(|v| v.as_bool()).unwrap_or(false);

    if let Some(id_str) = id_str {
        if let Ok(announcement_id) = Uuid::parse_str(id_str) {
            match crate::services::management::coordinator_service::pin_announcement(&state.pool, announcement_id, is_pinned).await {
                Ok(affected) if affected > 0 => (StatusCode::OK, Json(json!({"message": "Announcement pinned status updated successfully"}))).into_response(),
                Ok(_) => (StatusCode::NOT_FOUND, Json(json!({"message": "Announcement not found"}))).into_response(),
                Err(_) => (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": "Failed to update announcement pin status"}))).into_response(),
            }
        } else {
            (StatusCode::BAD_REQUEST, Json(json!({"message": "Invalid announcement ID format"}))).into_response()
        }
    } else {
        (StatusCode::BAD_REQUEST, Json(json!({"message": "Announcement ID is required"}))).into_response()
    }
}

pub async fn get_all_branches_syllabus_progress_handler(
    State(state): State<AppState>,
    Query(params): Query<serde_json::Value>,
) -> impl IntoResponse {
    let course_id = params.get("courseId").and_then(|v| v.as_str()).unwrap_or("C-23");
    match crate::services::management::coordinator_service::get_all_branches_syllabus_progress(&state.pool, course_id).await {
        Ok(res) => (StatusCode::OK, Json(res)).into_response(),
        Err(_) => (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": "Failed to fetch progress"}))).into_response(),
    }
}
