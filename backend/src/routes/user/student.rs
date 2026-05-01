use axum::{
    extract::{State, Query},
    Json, http::StatusCode,
};
use crate::models::{
    AppState, ProfileQuery, ProfileUpdateRequestData, LessonPlanQuery, 
    LessonPlanFeedbackRequest, AttendanceQuery, AttendanceCorrectionRequestData,
    DeleteCorrectionRequestsRequest, SemesterAcademicsResponse
};
use crate::services::user::student_service;

pub async fn get_student_profile_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::get_student_profile(&state.pool, &params.user_id).await {
        Ok(profile) => Ok(Json(serde_json::to_value(profile).unwrap())),
        Err(status) => Err((status, Json(serde_json::json!({"error": "Profile not found"})))),
    }
}

pub async fn request_profile_update_handler(
    State(state): State<AppState>,
    Json(payload): Json<ProfileUpdateRequestData>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match student_service::request_profile_update(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}

pub async fn get_student_courses_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::get_student_courses(&state.pool, &params.user_id).await {
        Ok(courses) => Ok(Json(serde_json::json!(courses))),
        Err(status) => Err((status, Json(serde_json::json!({"error": "Courses not found"})))),
    }
}

pub async fn get_student_lesson_plan_handler(
    State(state): State<AppState>,
    Query(params): Query<LessonPlanQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::get_student_lesson_plan(
        &state.pool, 
        &params.subject_id, 
        params.section, 
        params.branch, 
        params.user_id
    ).await {
        Ok(res) => Ok(Json(serde_json::json!(res))),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}

pub async fn submit_lesson_plan_feedback_handler(
    State(state): State<AppState>,
    Json(payload): Json<LessonPlanFeedbackRequest>,
) -> Result<StatusCode, StatusCode> {
    student_service::submit_lesson_plan_feedback(&state.pool, payload).await?;
    Ok(StatusCode::OK)
}

pub async fn delete_lesson_plan_feedback_handler(
    State(state): State<AppState>,
    Query(params): Query<crate::models::DeleteFeedbackQuery>,
    axum::extract::Path(feedback_id): axum::extract::Path<uuid::Uuid>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match student_service::delete_lesson_plan_feedback(&state.pool, feedback_id, params.user_id).await {
        Ok(_) => Ok(StatusCode::OK),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}

pub async fn get_lesson_plan_feedback_handler(
    State(state): State<AppState>,
    Query(params): Query<crate::models::GetFeedbackQuery>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let feedbacks = student_service::get_lesson_plan_feedback(&state.pool, &params.lesson_plan_id).await?;
    Ok(Json(serde_json::json!(feedbacks)))
}

pub async fn get_student_all_feedbacks_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::get_student_all_feedbacks(&state.pool, &params.user_id).await {
        Ok(res) => Ok(Json(serde_json::json!(res))),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}

pub async fn get_student_attendance_handler(
    State(state): State<AppState>,
    Query(params): Query<AttendanceQuery>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let summary = student_service::get_student_attendance(&state.pool, &params.student_id).await?;
    Ok(Json(serde_json::to_value(summary).unwrap()))
}

pub async fn request_attendance_correction_handler(
    State(state): State<AppState>,
    Json(payload): Json<AttendanceCorrectionRequestData>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::request_attendance_correction(&state.pool, payload).await {
        Ok(id) => Ok(Json(serde_json::json!({"id": id}))),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}

pub async fn get_attendance_correction_requests_handler(
    State(state): State<AppState>,
    axum::extract::Path(student_id): axum::extract::Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::get_attendance_correction_requests(&state.pool, &student_id).await {
        Ok(res) => Ok(Json(serde_json::json!(res))),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}

pub async fn delete_attendance_correction_requests_handler(
    State(state): State<AppState>,
    Json(payload): Json<DeleteCorrectionRequestsRequest>,
) -> Result<StatusCode, StatusCode> {
    student_service::delete_attendance_correction_requests(&state.pool, payload.ids)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::OK)
}

// --- Academics ---

pub async fn get_student_academics_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<Vec<SemesterAcademicsResponse>>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::get_student_academics(&state.pool, &params.user_id).await {
        Ok(res) => Ok(Json(res)),
        Err((c, msg)) => Err((c, Json(serde_json::json!({"error": msg})))),
    }
}
