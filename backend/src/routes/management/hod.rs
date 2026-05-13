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
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match hod_service::get_hod_departments(&data.pool).await {
        Ok(res) => {
            println!("GET HOD Departments Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Departments fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET HOD Departments Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch departments",
                "data": null
            }))))
        },
    }
}

pub async fn get_hod_sections_handler(
    State(data): State<AppState>,
    Query(params): Query<SectionQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match hod_service::get_hod_sections(&data.pool, params).await {
        Ok(res) => {
            println!("GET HOD Sections Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Sections fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET HOD Sections Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch sections",
                "data": null
            }))))
        },
    }
}

pub async fn get_hod_subjects_handler(
    State(data): State<AppState>,
    Query(params): Query<SubjectQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match hod_service::get_hod_subjects(&data.pool, params).await {
        Ok(res) => {
            println!("GET HOD Subjects Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Subjects fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET HOD Subjects Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch subjects",
                "data": null
            }))))
        },
    }
}

pub async fn add_course_subject_handler(
    State(data): State<AppState>,
    Json(payload): Json<AddCourseSubjectRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match hod_service::add_course_subject(&data.pool, payload).await {
        Ok(res) => {
            println!("ADD Course Subject Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Subject added successfully",
                "data": res
            })))
        },
        Err((c, msg)) => {
            println!("ADD Course Subject Error: {:?}", msg);
            Err((c, Json(json!({
                "success": false,
                "message": msg,
                "data": null
            }))))
        },
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
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match hod_service::get_all_staff(&data.pool).await {
        Ok(res) => {
            println!("GET All Staff Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Staff list fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET All Staff Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch staff list",
                "data": null
            }))))
        },
    }
}

pub async fn get_master_timetable_handler(
    State(data): State<AppState>,
    Query(params): Query<MasterTimetableQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match hod_service::get_master_timetable(&data.pool, params).await {
        Ok(res) => {
            println!("GET Master Timetable Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Master timetable fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Master Timetable Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch master timetable",
                "data": null
            }))))
        },
    }
}

pub async fn get_faculty_assignment_handler(
    State(data): State<AppState>,
    Query(params): Query<FacultyAssignmentQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match hod_service::get_faculty_assignment(&data.pool, params).await {
        Ok(res) => {
            println!("GET Faculty Assignment Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Faculty assignment fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Faculty Assignment Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch faculty assignment",
                "data": null
            }))))
        },
    }
}

pub async fn get_branch_progress_handler(
    State(data): State<AppState>,
    Query(params): Query<BranchProgressQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match hod_service::get_branch_progress(&data.pool, params).await {
        Ok(res) => {
            println!("GET Branch Progress Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Branch progress fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Branch Progress Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch branch progress",
                "data": null
            }))))
        },
    }
}

pub async fn get_year_sections_progress_handler(
    State(data): State<AppState>,
    Query(params): Query<YearSectionsProgressQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match hod_service::get_year_sections_progress(&data.pool, params).await {
        Ok(res) => {
            println!("GET Year Progress Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Year progress fetched",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Year Progress Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch year progress",
                "data": null
            }))))
        },
    }
}

pub async fn get_section_subjects_progress_handler(
    State(data): State<AppState>,
    Query(params): Query<SectionSubjectsProgressQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match hod_service::get_section_subjects_progress(&data.pool, params).await {
        Ok(res) => {
            println!("GET Section Subjects Progress Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Section subjects progress fetched",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Section Subjects Progress Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch section subjects progress",
                "data": null
            }))))
        },
    }
}
