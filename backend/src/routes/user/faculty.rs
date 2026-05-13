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
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::get_faculty_profile(&state.pool, &params.user_id).await {
        Ok(res) => {
            println!("GET Profile Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Profile fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Profile Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch profile",
                "data": null
            }))))
        },
    }
}

// --- Faculty Subjects ---

pub async fn get_faculty_subjects_handler(
    State(state): State<AppState>,
    Query(params): Query<FacultyQueryParams>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::get_faculty_subjects(&state.pool, params.user_id).await {
        Ok(res) => {
            println!("GET Subjects Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Subjects fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Subjects Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch subjects",
                "data": null
            }))))
        },
    }
}

pub async fn add_faculty_subject_handler(
    State(state): State<AppState>,
    Json(payload): Json<AddFacultySubjectRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::add_faculty_subject(&state.pool, payload).await {
        Ok(res) => {
            println!("ADD Subject Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Subject added successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("ADD Subject Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to add subject",
                "data": null
            }))))
        },
    }
}

pub async fn remove_faculty_subject_handler(
    State(state): State<AppState>,
    Json(payload): Json<RemoveFacultySubjectRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::remove_faculty_subject(&state.pool, payload).await {
        Ok(res) => {
            println!("REMOVE Subject Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Subject removed successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("REMOVE Subject Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to remove subject",
                "data": null
            }))))
        },
    }
}

// --- Lesson Plan ---

pub async fn mark_lesson_plan_complete_handler(
    State(state): State<AppState>,
    Json(payload): Json<MarkCompleteRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::mark_lesson_plan_complete(&state.pool, payload).await {
        Ok(res) => {
            println!("MARK Complete Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Lesson plan marked complete",
                "data": res
            })))
        },
        Err(e) => {
            println!("MARK Complete Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to mark complete",
                "data": null
            }))))
        },
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
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::get_students(&state.pool, params).await {
        Ok(res) => {
            println!("GET Students Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Students fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Students Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch students",
                "data": null
            }))))
        },
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
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::submit_attendance(&state.pool, payload).await {
        Ok(res) => {
            println!("SUBMIT Attendance Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Attendance submitted successfully",
                "data": res
            })))
        },
        Err((c, msg)) => {
            println!("SUBMIT Attendance Error: {:?}", msg);
            Err((c, Json(json!({
                "success": false,
                "message": msg,
                "data": null
            }))))
        },
    }
}

pub async fn submit_attendance_batch_handler(
    State(state): State<AppState>,
    Json(payload): Json<BatchAttendanceRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::submit_attendance_batch(&state.pool, payload).await {
        Ok(res) => Ok(Json(json!({
            "success": true,
            "message": "Batch attendance submitted",
            "data": res
        }))),
        Err((c, msg)) => Err((c, Json(json!({
            "success": false,
            "message": msg,
            "data": null
        })))),
    }
}

pub async fn check_attendance_status_handler(
    State(state): State<AppState>,
    Query(params): Query<CheckAttendanceQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::check_attendance_status(&state.pool, params).await {
        Ok(res) => Ok(Json(json!({
            "success": true,
            "message": "Status checked",
            "data": res
        }))),
        Err(e) => Err((e, Json(json!({
            "success": false,
            "message": "Failed to check status",
            "data": null
        })))),
    }
}

pub async fn get_class_attendance_record_handler(
    State(state): State<AppState>,
    Query(params): Query<ClassRecordQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::get_class_attendance_record(&state.pool, params).await {
        Ok(res) => {
            println!("GET Class Record Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Class record fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Class Record Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch class record",
                "data": null
            }))))
        },
    }
}

pub async fn get_attendance_stats_handler(
    State(state): State<AppState>,
    Query(params): Query<AttendanceStatsQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::get_attendance_stats_v2(&state.pool, params).await {
        Ok(res) => {
            println!("GET Attendance Stats Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Attendance stats fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Attendance Stats Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch attendance stats",
                "data": null
            }))))
        },
    }
}

pub async fn get_absent_students_handler(
    State(state): State<AppState>,
    Query(params): Query<AttendanceStatsQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::get_absent_students(&state.pool, params).await {
        Ok(res) => {
            println!("GET Absents Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Absent students fetched",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Absents Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch absents",
                "data": null
            }))))
        },
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
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::create_student(&state.pool, payload).await {
        Ok(res) => {
            println!("CREATE Student Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Student created successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("CREATE Student Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to create student",
                "data": null
            }))))
        },
    }
}

pub async fn bulk_create_students_handler(
    State(state): State<AppState>,
    Json(payloads): Json<Vec<CreateStudentRequest>>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::bulk_create_students(&state.pool, payloads).await {
        Ok(res) => {
            println!("BULK CREATE Students Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Students created successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("BULK CREATE Students Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to bulk create students",
                "data": null
            }))))
        },
    }
}

pub async fn get_sections_handler(
    State(state): State<AppState>,
    Query(params): Query<SectionsQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::get_sections(&state.pool, params).await {
        Ok(res) => {
            println!("GET Sections Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Sections fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Sections Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch sections",
                "data": null
            }))))
        },
    }
}

pub async fn update_sections_handler(
    State(state): State<AppState>,
    Json(payload): Json<UpdateSectionsRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::update_sections(&state.pool, payload).await {
        Ok(res) => {
            println!("UPDATE Sections Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Sections updated successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("UPDATE Sections Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to update sections",
                "data": null
            }))))
        },
    }
}

pub async fn delete_student_handler(
    State(state): State<AppState>,
    Json(payload): Json<DeleteStudentRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::delete_user(&state.pool, &payload.student_id).await {
        Ok(affected) if affected > 0 => {
            println!("DELETE Student Affected: {}", affected);
            Ok(Json(json!({
                "success": true,
                "message": "Student deleted successfully",
                "data": affected
            })))
        },
        Ok(_) => {
            println!("DELETE Student Not Found");
            Err((StatusCode::NOT_FOUND, Json(json!({
                "success": false,
                "message": "Student not found",
                "data": null
            }))))
        },
        Err(e) => {
            println!("DELETE Student Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to delete student",
                "data": null
            }))))
        },
    }
}

pub async fn rename_section_handler(
    State(state): State<AppState>,
    Json(payload): Json<RenameSectionRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::rename_section(&state.pool, payload).await {
        Ok(res) => {
            println!("RENAME Section Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Section renamed successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("RENAME Section Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to rename section",
                "data": null
            }))))
        },
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
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::get_timetable(&state.pool, params).await {
        Ok(res) => {
            println!("GET Timetable Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Timetable fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Timetable Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch timetable",
                "data": null
            }))))
        },
    }
}

pub async fn clear_class_handler(
    State(state): State<AppState>,
    Json(payload): Json<AssignClassRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::clear_class(&state.pool, payload).await {
        Ok(res) => {
            println!("CLEAR Class Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Class cleared successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("CLEAR Class Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to clear class",
                "data": null
            }))))
        },
    }
}

// --- Department Timings ---

pub async fn get_department_timings(
    State(state): State<AppState>,
    Query(params): Query<std::collections::HashMap<String, String>>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::get_department_timings(&state.pool, params.get("branch").map(|s| s.as_str())).await {
        Ok(res) => {
            println!("GET Timings Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Timings fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Timings Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch timings",
                "data": null
            }))))
        },
    }
}

pub async fn update_department_timings(
    State(state): State<AppState>,
    Json(payload): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::update_department_timings(&state.pool, payload).await {
        Ok(res) => {
            println!("UPDATE Timings Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Timings updated successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("UPDATE Timings Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to update timings",
                "data": null
            }))))
        },
    }
}

// --- HOD Syllabus Management ---

pub async fn get_courses_handler(
    State(state): State<AppState>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::get_courses(&state.pool).await {
        Ok(res) => {
            println!("GET Courses Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Courses fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Courses Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch courses",
                "data": null
            }))))
        },
    }
}

pub async fn get_semester_subjects_handler(
    State(state): State<AppState>,
    Query(params): Query<SemesterSubjectsQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::get_semester_subjects(&state.pool, params).await {
        Ok(res) => {
            println!("GET Sem Subjects Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Semester subjects fetched",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Sem Subjects Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch semester subjects",
                "data": null
            }))))
        },
    }
}

pub async fn get_lesson_topics_handler(
    State(state): State<AppState>,
    Query(params): Query<LessonTopicsQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::get_lesson_topics(&state.pool, params).await {
        Ok(res) => {
            println!("GET Topics Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Lesson topics fetched",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Topics Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch topics",
                "data": null
            }))))
        },
    }
}

pub async fn assign_lesson_schedule_handler(
    State(state): State<AppState>,
    Json(payload): Json<AssignLessonScheduleRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::user::faculty_service::assign_lesson_schedule(&state.pool, payload).await {
        Ok(res) => {
            println!("ASSIGN Schedule Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Lesson schedule assigned successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("ASSIGN Schedule Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to assign schedule",
                "data": null
            }))))
        },
    }
}
