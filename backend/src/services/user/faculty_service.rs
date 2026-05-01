use sqlx::{PgPool};
use axum::http::StatusCode;
use uuid::Uuid;
use crate::models::{
    FacultyProfileResponse, FacultySubjectResponse, StudentBasicInfo, 
    FacultyListDTO, StudentsQuery, FacultyByBranchQuery, AttendanceStatsQuery,
    AddFacultySubjectRequest, RemoveFacultySubjectRequest, MarkCompleteRequest,
    ReplyFeedbackRequest, MoveStudentsRequest, SubmitAttendanceRequest,
    BatchAttendanceRequest, CheckAttendanceQuery, ClassRecordQuery,
    ApprovalRequest, ApproveSubjectRequest, ApproveProfileChangeRequest,
    ApproveAttendanceCorrectionData, CreateStudentRequest, UpdateSectionsRequest,
    RenameSectionRequest, AssignClassRequest, AssignLessonScheduleRequest,
    SemesterSubjectsQuery, LessonTopicsQuery, SectionsQuery, CourseResponse,
    SemesterSubjectResponse, LessonTopicResponse, StudentAttendanceItem,
    AttendanceStatsResponse
};
use crate::repositories::user::faculty_repository;
use crate::utils::user_utils::resolve_user_id;

pub async fn get_faculty_profile(pool: &PgPool, user_id: &str) -> Result<FacultyProfileResponse, StatusCode> {
    let user_uuid = resolve_user_id(user_id, "Faculty", pool).await.map_err(|_| StatusCode::BAD_REQUEST)?;
    faculty_repository::find_profile_by_id(pool, user_uuid)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)
}

pub async fn get_faculty_subjects(pool: &PgPool, user_id: Uuid) -> Result<Vec<FacultySubjectResponse>, StatusCode> {
    faculty_repository::find_subjects_by_user_id(pool, user_id)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn add_faculty_subject(pool: &PgPool, payload: AddFacultySubjectRequest) -> Result<(), StatusCode> {
    faculty_repository::insert_faculty_subject(pool, payload.user_id, &payload.subject_id, &payload.subject_name, &payload.branch, payload.section.as_deref())
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn remove_faculty_subject(pool: &PgPool, payload: RemoveFacultySubjectRequest) -> Result<(), StatusCode> {
    faculty_repository::delete_faculty_subject(pool, payload.user_id, &payload.subject_id, payload.section.as_deref())
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn mark_lesson_plan_complete(pool: &PgPool, payload: MarkCompleteRequest) -> Result<(), StatusCode> {
    faculty_repository::update_lesson_plan_complete(pool, &payload.item_id, payload.section.as_deref().unwrap_or(""), payload.completed)
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn reply_to_feedback(pool: &PgPool, payload: ReplyFeedbackRequest) -> Result<(), StatusCode> {
    faculty_repository::update_feedback_reply(pool, payload.feedback_id, &payload.reply)
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_faculty_feedbacks(pool: &PgPool, faculty_id: String) -> Result<Vec<crate::models::FacultyFeedbackResponse>, StatusCode> {
    faculty_repository::find_feedbacks_by_faculty_id(pool, &faculty_id)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_students(pool: &PgPool, params: StudentsQuery) -> Result<Vec<StudentBasicInfo>, StatusCode> {
    faculty_repository::find_students(pool, params)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_faculty_by_branch(pool: &PgPool, params: FacultyByBranchQuery) -> Result<Vec<FacultyListDTO>, StatusCode> {
    faculty_repository::find_faculty_by_branch(pool, params)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn move_students(pool: &PgPool, payload: MoveStudentsRequest) -> Result<(), StatusCode> {
    faculty_repository::update_students_section(pool, &payload.student_ids, payload.target_section.as_deref().unwrap_or(""))
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn submit_attendance(pool: &PgPool, payload: SubmitAttendanceRequest) -> Result<(), (StatusCode, String)> {
    let mut tx = pool.begin().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Failed to start transaction".to_string()))?;
    
    let user_uuid = resolve_user_id(&payload.student_id, "Student", pool).await.map_err(|_| (StatusCode::BAD_REQUEST, format!("Invalid Student ID: {}", payload.student_id)))?;
    let session = payload.session.as_deref().unwrap_or("1");
    
    faculty_repository::insert_attendance(&mut tx, user_uuid, &payload.date, &payload.status, session, "")
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    tx.commit().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Failed to commit transaction".to_string()))?;
    Ok(())
}

pub async fn submit_attendance_batch(pool: &PgPool, payload: BatchAttendanceRequest) -> Result<serde_json::Value, (StatusCode, String)> {
    let mut tx = pool.begin().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Failed to start transaction".to_string()))?;
    
    let session = payload.session.unwrap_or_else(|| "1".to_string());
    
    for record in payload.records {
        let user_uuid = resolve_user_id(&record.student_id, "Student", pool).await.map_err(|_| (StatusCode::BAD_REQUEST, format!("Invalid Student ID: {}", record.student_id)))?;
        faculty_repository::insert_attendance(&mut tx, user_uuid, &payload.date, &record.status, &session, &payload.section)
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    }

    tx.commit().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Failed to commit transaction".to_string()))?;
    Ok(serde_json::json!({"message": "Batch attendance submitted"}))
}

pub async fn check_attendance_status(pool: &PgPool, params: CheckAttendanceQuery) -> Result<serde_json::Value, StatusCode> {
    let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM attendance WHERE date = $1 AND session = $2 AND section = $3")
        .bind(&params.date).bind(&params.session).bind(&params.section)
        .fetch_one(pool).await.unwrap_or(0);
    
    Ok(serde_json::json!({ "marked": count > 0 }))
}

pub async fn get_class_attendance_record(pool: &PgPool, params: ClassRecordQuery) -> Result<crate::models::ClassRecordResponse, StatusCode> {
    let mut query = sqlx::QueryBuilder::new("SELECT u.login_id as student_id, u.full_name, a.status FROM users u LEFT JOIN attendance a ON u.id = a.student_uuid AND a.date = ");
    query.push_bind(&params.date);
    query.push(" AND a.session = ");
    query.push_bind(&params.session);
    query.push(" WHERE u.role = 'Student' AND u.branch = ");
    query.push_bind(&params.branch);
    query.push(" AND u.year = ");
    query.push_bind(&params.year);
    query.push(" AND u.section = ");
    query.push_bind(&params.section);
    query.push(" ORDER BY u.login_id ASC");

    use sqlx::Row;
    let rows = query.build().fetch_all(pool).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    let students: Vec<crate::models::StudentAttendanceItem> = rows.into_iter().map(|r| crate::models::StudentAttendanceItem {
        id: Uuid::nil(), // Not needed here
        student_id: r.get("student_id"),
        full_name: r.get("full_name"),
        status: r.get::<Option<String>, _>("status").unwrap_or_else(|| "not marked".to_string())
    }).collect();

    Ok(crate::models::ClassRecordResponse { 
        marked: !students.is_empty() && students.iter().any(|s| s.status != "not marked"),
        marked_by: None,
        students 
    })
}

pub async fn create_student(pool: &PgPool, payload: CreateStudentRequest) -> Result<(), StatusCode> {
    faculty_repository::insert_user(pool, &payload)
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn bulk_create_students(pool: &PgPool, payloads: Vec<CreateStudentRequest>) -> Result<(), StatusCode> {
    for p in payloads {
        faculty_repository::insert_user(pool, &p)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    }
    Ok(())
}

pub async fn get_attendance_stats_v2(pool: &PgPool, params: AttendanceStatsQuery) -> Result<AttendanceStatsResponse, StatusCode> {
    let year = params.year.as_deref().unwrap_or("Unknown");
    let section = params.section.as_deref().unwrap_or("Section A");
    let stats = faculty_repository::find_attendance_status(pool, &params.branch, year, section, &params.date, params.session.as_deref())
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    serde_json::from_value(stats).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_absent_students(pool: &PgPool, params: AttendanceStatsQuery) -> Result<Vec<StudentAttendanceItem>, StatusCode> {
    let year = params.year.as_deref().unwrap_or("Unknown");
    let section = params.section.as_deref().unwrap_or("Section A");
    faculty_repository::find_absent_students(pool, &params.branch, year, section, &params.date, params.session.as_deref())
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn approve_user(pool: &PgPool, payload: ApprovalRequest) -> Result<(), StatusCode> {
    let status = payload.action == "APPROVE";
    faculty_repository::approve_user_status(pool, payload.user_id, status)
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn approve_subject(pool: &PgPool, payload: ApproveSubjectRequest) -> Result<(), (StatusCode, String)> {
    let notif = faculty_repository::find_notification_by_id(pool, payload.notification_id).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?.ok_or((StatusCode::NOT_FOUND, "Notif not found".to_string()))?;
    
    let sender_id = notif["sender_id"].as_str().unwrap_or_default();
    let user_uuid = resolve_user_id(sender_id, "Faculty", pool).await.map_err(|_| (StatusCode::BAD_REQUEST, "Invalid sender".to_string()))?;

    faculty_repository::update_faculty_subject_status(pool, user_uuid, &payload.sender_id, &payload.action).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    faculty_repository::delete_notification(pool, payload.notification_id).await.ok();

    Ok(())
}

pub async fn approve_profile_change(pool: &PgPool, payload: ApproveProfileChangeRequest) -> Result<(), (StatusCode, String)> {
    let mut tx = pool.begin().await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    
    if payload.action == "APPROVE" {
        let new_data = faculty_repository::find_profile_update_request(pool, payload.user_id).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?.ok_or((StatusCode::NOT_FOUND, "Request not found".to_string()))?;
        
        let profile_data: crate::models::ProfileUpdateRequestData = serde_json::from_value(new_data).map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
        faculty_repository::update_user_profile(&mut tx, payload.user_id, &profile_data).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    }

    faculty_repository::update_profile_request_status(&mut tx, payload.user_id, if payload.action == "APPROVE" { "APPROVED" } else { "REJECTED" }).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    tx.commit().await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    Ok(())
}

pub async fn approve_attendance_correction(pool: &PgPool, payload: ApproveAttendanceCorrectionData) -> Result<(), (StatusCode, String)> {
    let mut tx = pool.begin().await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    
    if payload.action == "APPROVE" {
        let request = faculty_repository::find_correction_request(pool, payload.request_id).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?.ok_or((StatusCode::NOT_FOUND, "Request not found".to_string()))?;
        let user_uuid = request["user_id"].as_str().and_then(|s| Uuid::parse_str(s).ok()).unwrap_or_default();
        let dates = request["dates"].as_array().cloned().unwrap_or_default();

        for d in dates {
            let date_str = d["date"].as_str().unwrap_or_default();
            let session = d["session"].as_str().unwrap_or_default();
            let section = d["section"].as_str().unwrap_or_default();
            faculty_repository::insert_attendance(&mut tx, user_uuid, date_str, "present", session, section).await.ok();
        }
    }

    faculty_repository::update_correction_request_status(&mut tx, payload.request_id, if payload.action == "APPROVE" { "APPROVED" } else { "REJECTED" }).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    tx.commit().await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    Ok(())
}

pub async fn delete_user(pool: &PgPool, student_id: &str) -> Result<u64, StatusCode> {
    let user_uuid = resolve_user_id(student_id, "Student", pool).await.map_err(|_| StatusCode::BAD_REQUEST)?;
    faculty_repository::delete_user(pool, user_uuid)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_sections(pool: &PgPool, params: SectionsQuery) -> Result<Vec<String>, StatusCode> {
    faculty_repository::find_sections(pool, &params.branch, &params.year)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn update_sections(pool: &PgPool, payload: UpdateSectionsRequest) -> Result<(), StatusCode> {
    faculty_repository::delete_sections_by_branch_year(pool, &payload.branch, &payload.year).await.ok();
    for s in payload.sections {
        faculty_repository::insert_section(pool, &payload.branch, &payload.year, &s).await.ok();
    }
    Ok(())
}

pub async fn rename_section(pool: &PgPool, payload: RenameSectionRequest) -> Result<(), StatusCode> {
    faculty_repository::update_section_name(pool, &payload.branch, &payload.year, &payload.old_name, &payload.new_name).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    faculty_repository::update_users_section_name(pool, &payload.branch, &payload.year, &payload.old_name, &payload.new_name).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(())
}

pub async fn assign_class(pool: &PgPool, payload: AssignClassRequest) -> Result<(), StatusCode> {
    faculty_repository::insert_timetable_entry(pool, &payload)
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_timetable(pool: &PgPool, params: std::collections::HashMap<String, String>) -> Result<Vec<crate::models::TimetableEntry>, StatusCode> {
    faculty_repository::find_timetable(pool, &params)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn clear_class(pool: &PgPool, payload: AssignClassRequest) -> Result<(), StatusCode> {
    faculty_repository::delete_timetable_entry(pool, &payload)
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_department_timings(pool: &PgPool, branch: Option<&str>) -> Result<Vec<crate::models::DepartmentTiming>, StatusCode> {
    faculty_repository::find_department_timings(pool, branch)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn update_department_timings(pool: &PgPool, payload: serde_json::Value) -> Result<(), StatusCode> {
    let branch = payload["branch"].as_str().unwrap_or("General");
    let start_time = payload["startTime"].as_str().unwrap_or("09:00");
    let end_time = payload["endTime"].as_str().unwrap_or("16:00");
    let total_periods = payload["totalPeriods"].as_i64().unwrap_or(7) as i32;
    let period_duration = payload["periodDuration"].as_i64().unwrap_or(50) as i32;
    let lunch_after = payload["lunchAfter"].as_i64().unwrap_or(4) as i32;
    let lunch_duration = payload["lunchDuration"].as_i64().unwrap_or(50) as i32;

    faculty_repository::insert_department_timing(pool, branch, start_time, end_time, total_periods, period_duration, lunch_after, lunch_duration)
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_courses(pool: &PgPool) -> Result<Vec<CourseResponse>, StatusCode> {
    faculty_repository::find_courses(pool)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_semester_subjects(pool: &PgPool, params: SemesterSubjectsQuery) -> Result<Vec<SemesterSubjectResponse>, StatusCode> {
    faculty_repository::find_semester_subjects(pool, params)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_lesson_topics(pool: &PgPool, params: LessonTopicsQuery) -> Result<Vec<LessonTopicResponse>, StatusCode> {
    faculty_repository::find_lesson_topics(pool, params)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn assign_lesson_schedule(pool: &PgPool, payload: AssignLessonScheduleRequest) -> Result<(), StatusCode> {
    let mut tx = pool.begin().await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    for item in payload.schedules {
        faculty_repository::insert_lesson_schedule(&mut tx, &item.topic_id.to_string(), &item.schedule_date, &item.branch, "Year", &item.section)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    }
    tx.commit().await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(())
}
