use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
use crate::models::{
    AppState, ProfileQuery, FacultyQueryParams, AddFacultySubjectRequest, 
    RemoveFacultySubjectRequest, MarkCompleteRequest, ReplyFeedbackRequest,
    StudentsQuery, FacultyByBranchQuery, MoveStudentsRequest, 
    SubmitAttendanceRequest, BatchAttendanceRequest, CheckAttendanceQuery,
    ClassRecordQuery, AttendanceStatsQuery, ApprovalRequest, ApproveSubjectRequest,
    ApproveProfileChangeRequest, ApproveAttendanceCorrectionData, CreateStudentRequest,
    SectionsQuery, UpdateSectionsRequest, DeleteStudentRequest, RenameSectionRequest,
    AssignClassRequest, AssignLessonScheduleRequest, SemesterSubjectsQuery,
    LessonTopicsQuery, FacultyFeedbackQuery
};
use serde_json::json;

// --- Faculty Profile ---

pub async fn get_faculty_profile_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<crate::models::FacultyProfileResponse>, StatusCode> {
    match crate::services::user::faculty_service::get_faculty_profile(&state.pool, &params.user_id).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

// --- Faculty Subjects ---

pub async fn get_faculty_subjects_handler(
    State(state): State<AppState>,
    Query(params): Query<FacultyQueryParams>,
) -> Result<Json<Vec<crate::models::FacultySubjectResponse>>, StatusCode> {
    match crate::services::user::faculty_service::get_faculty_subjects(&state.pool, params.user_id).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn add_faculty_subject_handler(
    State(state): State<AppState>,
    Json(payload): Json<AddFacultySubjectRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::add_faculty_subject(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err((e, Json(json!({"error": "Failed to add subject"})))),
    }
}

pub async fn remove_faculty_subject_handler(
    State(state): State<AppState>,
    Json(payload): Json<RemoveFacultySubjectRequest>,
) -> Result<StatusCode, StatusCode> {
    match crate::services::user::faculty_service::remove_faculty_subject(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err(e),
    }
}

// --- Lesson Plan ---

pub async fn mark_lesson_plan_complete_handler(
    State(state): State<AppState>,
    Json(payload): Json<MarkCompleteRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::mark_lesson_plan_complete(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err((e, Json(json!({"error": "Failed to mark complete"})))),
    }
}

pub async fn reply_to_feedback_handler(
    State(state): State<AppState>,
    Json(payload): Json<ReplyFeedbackRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::reply_to_feedback(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err((e, Json(json!({"error": "Failed to reply to feedback"})))),
    }
}

// --- Faculty Feedback ---

pub async fn get_faculty_feedbacks_handler(
    State(state): State<AppState>,
    Query(params): Query<FacultyFeedbackQuery>,
) -> Result<Json<Vec<crate::models::FacultyFeedbackResponse>>, StatusCode> {
    match crate::services::user::faculty_service::get_faculty_feedbacks(&state.pool, params.faculty_id.to_string()).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

// --- Students View ---

pub async fn get_students_handler(
    State(state): State<AppState>,
    Query(params): Query<StudentsQuery>,
) -> Result<Json<Vec<crate::models::StudentBasicInfo>>, StatusCode> {
    match crate::services::user::faculty_service::get_students(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_faculty_by_branch_handler(
    State(state): State<AppState>,
    Query(params): Query<FacultyByBranchQuery>,
) -> Result<Json<Vec<crate::models::FacultyListDTO>>, StatusCode> {
    match crate::services::user::faculty_service::get_faculty_by_branch(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn move_students_handler(
    State(state): State<AppState>,
    Json(payload): Json<MoveStudentsRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::move_students(&state.pool, payload).await {
        Ok(_) => Ok(Json(json!({"success": true, "message": "Students moved successfully"}))),
        Err(e) => Err((e, Json(json!({"success": false, "message": "Failed to move students"})))),
    }
}

// --- Attendance ---

pub async fn submit_attendance_handler(
    State(state): State<AppState>,
    Json(payload): Json<SubmitAttendanceRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::submit_attendance(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err((c, msg)) => Err((c, Json(json!({"error": msg})))),
    }
}

pub async fn submit_attendance_batch_handler(
    State(state): State<AppState>,
    Json(payload): Json<BatchAttendanceRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::submit_attendance_batch(&state.pool, payload).await {
        Ok(res) => Ok(Json(res)),
        Err((c, msg)) => Err((c, Json(json!({"error": msg})))),
    }
}

pub async fn check_attendance_status_handler(
    State(state): State<AppState>,
    Query(params): Query<CheckAttendanceQuery>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    match crate::services::user::faculty_service::check_attendance_status(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_class_attendance_record_handler(
    State(state): State<AppState>,
    Query(params): Query<ClassRecordQuery>,
) -> Result<Json<crate::models::ClassRecordResponse>, StatusCode> {
    match crate::services::user::faculty_service::get_class_attendance_record(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_attendance_stats_handler(
    State(state): State<AppState>,
    Query(params): Query<AttendanceStatsQuery>,
) -> Result<Json<crate::models::AttendanceStatsResponse>, StatusCode> {
    match crate::services::user::faculty_service::get_attendance_stats_v2(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_absent_students_handler(
    State(state): State<AppState>,
    Query(params): Query<AttendanceStatsQuery>,
) -> Result<Json<Vec<crate::models::StudentAttendanceItem>>, StatusCode> {
    match crate::services::user::faculty_service::get_absent_students(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

// --- HOD Actions ---

pub async fn approve_handler(
    State(state): State<AppState>,
    Json(payload): Json<ApprovalRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::approve_user(&state.pool, payload).await {
        Ok(_) => Ok(Json(json!({"success": true, "message": "Approved successfully"}))),
        Err(e) => Err((e, Json(json!({"error": "Failed to approve user"})))),
    }
}

pub async fn approve_subject_handler(
    State(state): State<AppState>,
    Json(payload): Json<ApproveSubjectRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::approve_subject(&state.pool, payload).await {
        Ok(_) => Ok(Json(json!({"success": true, "message": "Subject approved"}))),
        Err((c, msg)) => Err((c, Json(json!({"error": msg})))),
    }
}

pub async fn approve_profile_change_handler(
    State(state): State<AppState>,
    Json(payload): Json<ApproveProfileChangeRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::approve_profile_change(&state.pool, payload).await {
        Ok(_) => Ok(Json(json!({"success": true, "message": "Profile change approved"}))),
        Err((c, msg)) => Err((c, Json(json!({"error": msg})))),
    }
}

pub async fn approve_attendance_correction_handler(
    State(state): State<AppState>,
    Json(payload): Json<ApproveAttendanceCorrectionData>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::approve_attendance_correction(&state.pool, payload).await {
        Ok(_) => Ok(Json(json!({"message": "Processed successfully"}))),
        Err((c, msg)) => Err((c, Json(json!({"error": msg})))),
    }
}

// --- Create Student (HOD) ---

pub async fn create_student_handler(
    State(state): State<AppState>,
    Json(payload): Json<CreateStudentRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::create_student(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::CREATED),
        Err(e) => Err((e, Json(json!({"error": "Failed to create student"})))),
    }
}

pub async fn bulk_create_students_handler(
    State(state): State<AppState>,
    Json(payloads): Json<Vec<CreateStudentRequest>>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::bulk_create_students(&state.pool, payloads).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err((e, Json(json!({"error": "Failed to bulk create students"})))),
    }
}

pub async fn get_sections_handler(
    State(state): State<AppState>,
    Query(params): Query<SectionsQuery>,
) -> Result<Json<Vec<String>>, StatusCode> {
    match crate::services::user::faculty_service::get_sections(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn update_sections_handler(
    State(state): State<AppState>,
    Json(payload): Json<UpdateSectionsRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::update_sections(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err((e, Json(json!({"error": "Failed to update sections"})))),
    }
}

pub async fn delete_student_handler(
    State(state): State<AppState>,
    Json(payload): Json<DeleteStudentRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::delete_user(&state.pool, &payload.student_id).await {
        Ok(affected) if affected > 0 => Ok(StatusCode::OK),
        Ok(_) => Err((StatusCode::NOT_FOUND, Json(json!({"error": "Student not found"})))),
        Err(e) => Err((e, Json(json!({"error": "Failed to delete student"})))),
    }
}

pub async fn rename_section_handler(
    State(state): State<AppState>,
    Json(payload): Json<RenameSectionRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::rename_section(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err((e, Json(json!({"error": "Failed to rename section"})))),
    }
}

// --- Timetable ---

pub async fn assign_class_handler(
    State(state): State<AppState>,
    Json(payload): Json<AssignClassRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::assign_class(&state.pool, payload).await {
        Ok(_) => Ok(Json(json!({"success": true, "message": "Class assigned successfully"}))),
        Err(e) => Err((e, Json(json!({"error": "Failed to assign class"})))),
    }
}

pub async fn get_timetable_handler(
    State(state): State<AppState>,
    Query(params): Query<std::collections::HashMap<String, String>>,
) -> Result<Json<Vec<crate::models::TimetableEntry>>, StatusCode> {
    match crate::services::user::faculty_service::get_timetable(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn clear_class_handler(
    State(state): State<AppState>,
    Json(payload): Json<AssignClassRequest>,
) -> Result<StatusCode, StatusCode> {
    match crate::services::user::faculty_service::clear_class(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err(e),
    }
}

// --- Department Timings ---

pub async fn get_department_timings(
    State(state): State<AppState>,
    Query(params): Query<std::collections::HashMap<String, String>>,
) -> Result<Json<Vec<crate::models::DepartmentTiming>>, StatusCode> {
    match crate::services::user::faculty_service::get_department_timings(&state.pool, params.get("branch").map(|s| s.as_str())).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn update_department_timings(
    State(state): State<AppState>,
    Json(payload): Json<serde_json::Value>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::update_department_timings(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err((e, Json(json!({"error": "Failed to update"})))),
    }
}

// --- HOD Syllabus Management ---

pub async fn get_courses_handler(
    State(state): State<AppState>,
) -> Result<Json<Vec<crate::models::CourseResponse>>, StatusCode> {
    match crate::services::user::faculty_service::get_courses(&state.pool).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_semester_subjects_handler(
    State(state): State<AppState>,
    Query(params): Query<SemesterSubjectsQuery>,
) -> Result<Json<Vec<crate::models::SemesterSubjectResponse>>, StatusCode> {
    match crate::services::user::faculty_service::get_semester_subjects(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_lesson_topics_handler(
    State(state): State<AppState>,
    Query(params): Query<LessonTopicsQuery>,
) -> Result<Json<Vec<crate::models::LessonTopicResponse>>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::get_lesson_topics(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err((e, Json(json!({"error": "DB Error"})))),
    }
}

pub async fn assign_lesson_schedule_handler(
    State(state): State<AppState>,
    Json(payload): Json<AssignLessonScheduleRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::assign_lesson_schedule(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => Err((e, Json(json!({"error": "Failed to assign schedule"})))),
    }
}
