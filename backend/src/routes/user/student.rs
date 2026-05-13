use axum::{
    extract::{State, Query},
    Json, http::StatusCode,
};
use crate::models::{
    AppState, ProfileQuery, ProfileUpdateRequestData, LessonPlanQuery, 
    LessonPlanFeedbackRequest, AttendanceQuery, AttendanceCorrectionRequestData,
    DeleteCorrectionRequestsRequest
};
use crate::services::user::student_service;
use serde_json::json;

pub async fn get_student_profile_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::get_student_profile(&state.pool, &params.user_id).await {
        Ok(profile) => {
            println!("GET Student Profile Result: {:?}", profile);
            Ok(Json(json!({
                "success": true,
                "message": "Profile fetched successfully",
                "data": profile
            })))
        },
        Err(status) => {
            println!("GET Student Profile Error: {:?}", status);
            Err((status, Json(json!({
                "success": false,
                "message": "Profile not found",
                "data": null
            }))))
        },
    }
}

pub async fn request_profile_update_handler(
    State(state): State<AppState>,
    Json(payload): Json<ProfileUpdateRequestData>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::request_profile_update(&state.pool, payload).await {
        Ok(res) => {
            println!("REQUEST Profile Update Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Update request submitted successfully",
                "data": res
            })))
        },
        Err((c, msg)) => {
            println!("REQUEST Profile Update Error: {:?}", msg);
            Err((c, Json(json!({
                "success": false,
                "message": msg,
                "data": null
            }))))
        },
    }
}

pub async fn get_student_courses_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::get_student_courses(&state.pool, &params.user_id).await {
        Ok(courses) => {
            println!("GET Student Courses Result: {:?}", courses.len());
            Ok(Json(json!({
                "success": true,
                "message": "Courses fetched successfully",
                "data": courses
            })))
        },
        Err(status) => {
            println!("GET Student Courses Error: {:?}", status);
            Err((status, Json(json!({
                "success": false,
                "message": "Courses not found",
                "data": null
            }))))
        },
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
        Ok(res) => {
            println!("GET Lesson Plan Result: {:?}", res.percentage);
            Ok(Json(json!({
                "success": true,
                "message": "Lesson plan fetched",
                "data": res
            })))
        },
        Err((c, msg)) => {
            println!("GET Lesson Plan Error: {:?}", msg);
            Err((c, Json(json!({
                "success": false,
                "message": msg,
                "data": null
            }))))
        },
    }
}

pub async fn submit_lesson_plan_feedback_handler(
    State(state): State<AppState>,
    Json(payload): Json<LessonPlanFeedbackRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::submit_lesson_plan_feedback(&state.pool, payload).await {
        Ok(res) => {
            println!("SUBMIT Feedback Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Feedback submitted successfully",
                "data": res
            })))
        },
        Err(status) => {
            println!("SUBMIT Feedback Error: {:?}", status);
            Err((status, Json(json!({
                "success": false,
                "message": "Failed to submit feedback",
                "data": null
            }))))
        },
    }
}

pub async fn delete_lesson_plan_feedback_handler(
    State(state): State<AppState>,
    Query(params): Query<crate::models::DeleteFeedbackQuery>,
    axum::extract::Path(feedback_id): axum::extract::Path<uuid::Uuid>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::delete_lesson_plan_feedback(&state.pool, feedback_id, params.user_id).await {
        Ok(res) => {
            println!("DELETE Feedback Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Feedback deleted successfully",
                "data": res
            })))
        },
        Err((c, msg)) => {
            println!("DELETE Feedback Error: {:?}", msg);
            Err((c, Json(json!({
                "success": false,
                "message": msg,
                "data": null
            }))))
        },
    }
}

pub async fn get_lesson_plan_feedback_handler(
    State(state): State<AppState>,
    Query(params): Query<crate::models::GetFeedbackQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::get_lesson_plan_feedback(&state.pool, &params.lesson_plan_id).await {
        Ok(feedbacks) => {
            println!("GET LP Feedbacks Result: {:?}", feedbacks.len());
            Ok(Json(json!({
                "success": true,
                "message": "Feedbacks fetched successfully",
                "data": feedbacks
            })))
        },
        Err(status) => {
            println!("GET LP Feedbacks Error: {:?}", status);
            Err((status, Json(json!({
                "success": false,
                "message": "Feedbacks not found",
                "data": null
            }))))
        },
    }
}

pub async fn get_student_all_feedbacks_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::get_student_all_feedbacks(&state.pool, &params.user_id).await {
        Ok(res) => {
            println!("GET All Feedbacks Result: {:?}", res.len());
            Ok(Json(json!({
                "success": true,
                "message": "All feedbacks fetched",
                "data": res
            })))
        },
        Err((c, msg)) => {
            println!("GET All Feedbacks Error: {:?}", msg);
            Err((c, Json(json!({
                "success": false,
                "message": msg,
                "data": null
            }))))
        },
    }
}

pub async fn get_student_attendance_handler(
    State(state): State<AppState>,
    Query(params): Query<AttendanceQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::get_student_attendance(&state.pool, &params.student_id).await {
        Ok(summary) => {
            println!("GET Student Attendance Result: {:?}", summary);
            Ok(Json(json!({
                "success": true,
                "message": "Attendance summary fetched successfully",
                "data": summary
            })))
        },
        Err(status) => {
            println!("GET Student Attendance Error: {:?}", status);
            Err((status, Json(json!({
                "success": false,
                "message": "Attendance summary not found",
                "data": null
            }))))
        },
    }
}

pub async fn request_attendance_correction_handler(
    State(state): State<AppState>,
    Json(payload): Json<AttendanceCorrectionRequestData>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::request_attendance_correction(&state.pool, payload).await {
        Ok(id) => {
            println!("REQUEST Attendance Correction Result: {:?}", id);
            Ok(Json(json!({
                "success": true,
                "message": "Attendance correction requested successfully",
                "data": {"id": id}
            })))
        },
        Err((c, msg)) => {
            println!("REQUEST Attendance Correction Error: {:?}", msg);
            Err((c, Json(json!({
                "success": false,
                "message": msg,
                "data": null
            }))))
        },
    }
}

pub async fn get_attendance_correction_requests_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::get_attendance_correction_requests(&state.pool, &params.user_id).await {
        Ok(res) => {
            println!("GET Correction Requests Result: {:?}", res.len());
            Ok(Json(json!({
                "success": true,
                "message": "Correction requests fetched",
                "data": res
            })))
        },
        Err((c, msg)) => {
            println!("GET Correction Requests Error: {:?}", msg);
            Err((c, Json(json!({
                "success": false,
                "message": msg,
                "data": null
            }))))
        },
    }
}

pub async fn delete_attendance_correction_requests_handler(
    State(state): State<AppState>,
    Json(payload): Json<DeleteCorrectionRequestsRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::delete_attendance_correction_requests(&state.pool, payload.ids).await {
        Ok(res) => {
            println!("DELETE Correction Requests Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Requests deleted successfully",
                "data": res
            })))
        },
        Err(status) => {
            println!("DELETE Correction Requests Error: {:?}", status);
            Err((status, Json(json!({
                "success": false,
                "message": "Failed to delete requests",
                "data": null
            }))))
        },
    }
}

// --- Academics ---

pub async fn get_student_academics_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match student_service::get_student_academics(&state.pool, &params.user_id).await {
        Ok(res) => {
            println!("GET Student Academics Result: {:?}", res.len());
            Ok(Json(json!({
                "success": true,
                "message": "Academics fetched successfully",
                "data": res
            })))
        },
        Err((c, msg)) => {
            println!("GET Student Academics Error: {:?}", msg);
            Err((c, Json(json!({
                "success": false,
                "message": msg,
                "data": null
            }))))
        },
    }
}
