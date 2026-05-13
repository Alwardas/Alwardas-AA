use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
use serde_json::json;
use crate::models::{
    AppState, MasterTimetableQuery, MasterTimetableResponse, 
    BranchProgressResponse, SectionProgressResponse, 
    SubjectProgressResponse, AddCourseSubjectRequest, SectionQuery, 
    SubjectQuery, FacultyAssignmentQuery, BranchProgressQuery, 
    YearSectionsProgressQuery, SectionSubjectsProgressQuery
};
use crate::services::management::hod_service;

pub async fn get_hod_departments_handler(
    State(data): State<AppState>,
) -> Result<Json<Vec<String>>, StatusCode> {
    match hod_service::get_hod_departments(&data.pool).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_hod_sections_handler(
    State(data): State<AppState>,
    Query(params): Query<SectionQuery>,
) -> Result<Json<Vec<String>>, StatusCode> {
    match hod_service::get_hod_sections(&data.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_hod_subjects_handler(
    State(data): State<AppState>,
    Query(params): Query<SubjectQuery>,
) -> Result<Json<Vec<String>>, StatusCode> {
    match hod_service::get_hod_subjects(&data.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn add_course_subject_handler(
    State(data): State<AppState>,
    Json(payload): Json<AddCourseSubjectRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match hod_service::add_course_subject(&data.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err((c, msg)) => Err((c, Json(json!({"error": msg})))),
    }
}

pub async fn get_added_course_subjects_handler(
    State(data): State<AppState>,
    Query(params): Query<crate::models::ProfileQuery>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    match hod_service::get_added_course_subjects(&data.pool, &params.user_id).await {
        Ok(res) => Ok(Json(json!({
            "success": true,
            "message": "Subjects fetched successfully",
            "data": res
        }))),
        Err(e) => Err(e),
    }
}

pub async fn get_all_staff_handler(
    State(data): State<AppState>,
) -> Result<Json<Vec<serde_json::Value>>, StatusCode> {
    match hod_service::get_all_staff(&data.pool).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_master_timetable_handler(
    State(data): State<AppState>,
    Query(params): Query<MasterTimetableQuery>,
) -> Result<Json<MasterTimetableResponse>, StatusCode> {
    match hod_service::get_master_timetable(&data.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_faculty_assignment_handler(
    State(data): State<AppState>,
    Query(params): Query<FacultyAssignmentQuery>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    match hod_service::get_faculty_assignment(&data.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_branch_progress_handler(
    State(data): State<AppState>,
    Query(params): Query<BranchProgressQuery>,
) -> Result<Json<BranchProgressResponse>, StatusCode> {
    match hod_service::get_branch_progress(&data.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_year_sections_progress_handler(
    State(data): State<AppState>,
    Query(params): Query<YearSectionsProgressQuery>,
) -> Result<Json<Vec<SectionProgressResponse>>, StatusCode> {
    match hod_service::get_year_sections_progress(&data.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_section_subjects_progress_handler(
    State(data): State<AppState>,
    Query(params): Query<SectionSubjectsProgressQuery>,
) -> Result<Json<Vec<SubjectProgressResponse>>, StatusCode> {
    match hod_service::get_section_subjects_progress(&data.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}
