use axum::{
    extract::{Query, State, Path},
    Json,
    response::IntoResponse,
};
use serde_json::json;
use crate::models::{AppState, ApiResponse};
use crate::models::curriculum::{UpdateProgressRequest, SubmitFeedbackRequest};
use crate::services::curriculum_service;
use crate::repositories::curriculum_repository;
use std::collections::HashMap;
use uuid::Uuid;

pub async fn get_merged_curriculum_handler(
    State(state): State<AppState>,
    Query(params): Query<HashMap<String, String>>,
) -> impl IntoResponse {
    let branch = params.get("branch").cloned().unwrap_or_default();
    let semester = params.get("semester").and_then(|s| s.parse::<i32>().ok()).unwrap_or(1);
    let regulation = params.get("regulation").cloned().unwrap_or_else(|| "C23".to_string());
    let subject_code = params.get("subjectCode").cloned().unwrap_or_default();
    let section = params.get("section").cloned().unwrap_or_default();
    let year = params.get("year").cloned().unwrap_or_default();

    match curriculum_service::get_merged_curriculum(
        &state.pool, &branch, semester, &regulation, &subject_code, &section, &year
    ).await {
        Ok(curriculum) => Json(ApiResponse {
            success: true,
            message: "Curriculum loaded successfully".to_string(),
            data: Some(curriculum),
        }),
        Err(e) => Json(ApiResponse {
            success: false,
            message: format!("Error loading curriculum: {}", e),
            data: None,
        }),
    }
}

pub async fn update_progress_handler(
    State(state): State<AppState>,
    Json(req): Json<UpdateProgressRequest>,
) -> impl IntoResponse {
    match curriculum_repository::upsert_progress(&state.pool, req).await {
        Ok(_) => Json(ApiResponse {
            success: true,
            message: "Progress updated successfully".to_string(),
            data: Some(true),
        }),
        Err(e) => Json(ApiResponse {
            success: false,
            message: format!("Error updating progress: {}", e),
            data: None,
        }),
    }
}

pub async fn submit_feedback_handler(
    State(state): State<AppState>,
    // In a real app, we'd get student_id from auth middleware
    Query(params): Query<HashMap<String, String>>,
    Json(req): Json<SubmitFeedbackRequest>,
) -> impl IntoResponse {
    let student_id_str = params.get("studentId").cloned().unwrap_or_default();
    let student_id = match Uuid::parse_str(&student_id_str) {
        Ok(id) => id,
        Err(_) => return Json(ApiResponse {
            success: false,
            message: "Invalid student ID".to_string(),
            data: None,
        }),
    };

    match curriculum_repository::insert_feedback(&state.pool, student_id, req).await {
        Ok(_) => Json(ApiResponse {
            success: true,
            message: "Feedback submitted successfully".to_string(),
            data: Some(true),
        }),
        Err(e) => Json(ApiResponse {
            success: false,
            message: format!("Error submitting feedback: {}", e),
            data: None,
        }),
    }
}
