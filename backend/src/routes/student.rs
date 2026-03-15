use axum::{
    extract::{State, Query, Path},
    Json,
    http::StatusCode,
};
use sqlx::{Postgres, Row};
use crate::models::*;
use uuid::Uuid;
use chrono::{DateTime, Utc};
use std::collections::HashMap;

use crate::routes::faculty::resolve_user_id;

// --- Profile ---

pub async fn get_student_profile_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<StudentProfileResponse>, StatusCode> {
    let user_uuid = resolve_user_id(&params.user_id, "Student", &state.pool).await.map_err(|_| StatusCode::BAD_REQUEST)?;

    let user_profile = sqlx::query_as::<Postgres, StudentProfileResponse>(
        "SELECT 
            u.full_name, u.login_id, u.branch, u.year, u.semester, u.dob, u.batch_no, u.section, u.phone_number, u.email,
            EXISTS(SELECT 1 FROM profile_update_requests WHERE user_id = u.id AND status = 'PENDING') as pending_update,
            COALESCE(p1.full_name, p2.full_name) as parent_name,
            COALESCE(p1.phone_number, p2.phone_number) as parent_phone,
            COALESCE(p1.email, p2.email) as parent_email
         FROM users u 
         LEFT JOIN parent_student ps ON u.login_id = ps.student_id
         LEFT JOIN users p1 ON ps.parent_id = p1.login_id AND p1.role = 'Parent'
         LEFT JOIN users p2 ON (CASE WHEN u.login_id NOT LIKE 'P-%' THEN 'P-' || u.login_id ELSE u.login_id END) = p2.login_id AND p2.role = 'Parent'
         WHERE u.id = $1"
    )
    .bind(user_uuid)
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| {
         eprintln!("Profile Fetch Error: {:?}", e);
         StatusCode::INTERNAL_SERVER_ERROR
    })?;

    match user_profile {
        Some(profile) => Ok(Json(profile)),
        None => Err(StatusCode::NOT_FOUND),
    }
}

pub async fn request_profile_update_handler(
    State(state): State<AppState>,
    Json(payload): Json<ProfileUpdateRequestData>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let user_uuid = Uuid::parse_str(&payload.user_id).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid User ID"}))))?;

    let branch_str = payload.new_branch.clone().or(payload.branch.clone()).unwrap_or_default();
    
    let json_data = serde_json::to_value(&payload).map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to serialize data"}))))?;

    let mut tx = state.pool.begin().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to start transaction"}))))?;

    // Delete existing pending requests for this user to avoid duplication
    sqlx::query("DELETE FROM profile_update_requests WHERE user_id = $1 AND status = 'PENDING'")
        .bind(user_uuid)
        .execute(&mut *tx)
        .await.ok();

    sqlx::query("INSERT INTO profile_update_requests (user_id, new_data, status) VALUES ($1, $2, 'PENDING')")
        .bind(user_uuid)
        .bind(json_data)
        .execute(&mut *tx)
        .await
        .map_err(|e| {
             eprintln!("Request Update Error: {:?}", e);
             (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to create request"})))
        })?;

    let branch_for_notif = if branch_str.is_empty() {
        let b: Option<String> = sqlx::query_scalar("SELECT branch FROM users WHERE id = $1")
             .bind(user_uuid)
             .fetch_optional(&mut *tx)
             .await
             .unwrap_or(None);
        b.unwrap_or_default()
    } else {
        branch_str
    };

    let (role_label, distinct_id, name) = if let Some(sid) = &payload.new_student_id {
        ("Student", sid.clone(), payload.new_full_name.clone().unwrap_or_default())
    } else if let Some(fid) = &payload.faculty_id {
        ("Faculty", fid.clone(), payload.full_name.clone().unwrap_or_default())
    } else {
        ("User", payload.user_id.clone(), "Unknown".to_string())
    };

    let msg = format!("{} {} ({}) requested profile update.", role_label, name, distinct_id);

    sqlx::query("INSERT INTO notifications (type, message, sender_id, branch, status) VALUES ($1, $2, $3, $4, 'UNREAD')")
        .bind("PROFILE_UPDATE_REQUEST")
        .bind(msg)
        .bind(user_uuid.to_string()) 
        .bind(branch_for_notif)
        .execute(&mut *tx)
        .await
        .map_err(|e| {
             eprintln!("Notif Error: {:?}", e);
             (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to create notification"})))
        })?;

    tx.commit().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to commit transaction"}))))?;

    Ok(StatusCode::OK)
}

// --- Courses ---

pub async fn get_student_courses_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<Vec<StudentCourse>>, StatusCode> {
    
    #[derive(sqlx::FromRow)]
    struct UserData {
        branch: Option<String>,
        year: Option<String>,
        semester: Option<String>,
        section: Option<String>,
    }

    let user_uuid = resolve_user_id(&params.user_id, "Student", &state.pool).await.map_err(|_| StatusCode::BAD_REQUEST)?;

    let user_opt = sqlx::query_as::<_, UserData>("SELECT branch, year, semester, section FROM users WHERE id = $1")
        .bind(user_uuid)
        .fetch_optional(&state.pool)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let user = match user_opt {
        Some(u) => u,
        None => return Err(StatusCode::NOT_FOUND),
    };

    let branch_norm = normalize_branch(&user.branch.unwrap_or_default());
    let year_str = user.year.unwrap_or_default();
    let sem_str = user.semester.unwrap_or_default();
    let section = user.section.unwrap_or_else(|| "Section A".to_string());

    // Normalize Semester Search 
    // If student is 1st Year, they usually take "1st Year" subjects (common for both sems)
    let semester_key = if year_str == "1st Year" {
        "1st Year".to_string()
    } else if !sem_str.is_empty() {
        sem_str
    } else {
        // Fallback guess based on year string
        if year_str.contains("2nd Year") || year_str.contains("3rd Semester") { "3rd Semester".to_string() }
        else if year_str.contains("4th Semester") { "4th Semester".to_string() }
        else if year_str.contains("3rd Year") || year_str.contains("5th Semester") { "5th Semester".to_string() }
        else if year_str.contains("6th Semester") { "6th Semester".to_string() }
        else { "1st Year".to_string() }
    };
    
    println!("DEBUG: Fetching courses for Branch='{}', Semester='{}', Section='{}'", branch_norm, semester_key, section);

    println!("DEBUG: Fetching courses for Branch='{}', Semester='{}', Section='{}'", branch_norm, semester_key, section);

    #[derive(sqlx::FromRow, Debug)]
    struct SubjectData {
        id: String,
        name: String,
        subject_type: String,
        resolved_faculty_name: Option<String>,
        faculty_email: Option<String>,
        faculty_phone: Option<String>,
        faculty_department: Option<String>,
    }

    let subjects = sqlx::query_as::<_, SubjectData>(
        r#"
        SELECT 
            s.id, 
            s.name, 
            s.type as subject_type,
            COALESCE(u.full_name, s.faculty_name, 'TBA') as resolved_faculty_name,
            u.email as faculty_email,
            u.phone_number as faculty_phone,
            u.branch as faculty_department
        FROM subjects s
        LEFT JOIN faculty_subjects fs ON s.id = fs.subject_id AND fs.branch = s.branch AND fs.status = 'APPROVED' AND fs.section = $3
        LEFT JOIN users u ON fs.user_id = u.id
        WHERE s.branch = $1 AND s.semester = $2
        ORDER BY s.id ASC
        "#
    )
    .bind(&branch_norm)
    .bind(semester_key)
    .bind(&section)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        eprintln!("Error fetching subjects: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    let mut courses = Vec::new();

    for s in subjects {
        // Calculate Progress & Status per subject
        // Count total items
        let total_items: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM lesson_plan_items WHERE subject_id = $1")
            .bind(&s.id)
            .fetch_one(&state.pool)
            .await
            .unwrap_or(0);

        // Count completed items for this section
        let completed_items: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM lesson_plan_items lpi 
             JOIN lesson_plan_progress lpp ON lpi.id = lpp.item_id 
             WHERE lpi.subject_id = $1 AND lpp.section = $2 AND lpp.completed = TRUE"
        )
        .bind(&s.id)
        .bind(&section)
        .fetch_one(&state.pool)
        .await
        .unwrap_or(0);

        let progress = if total_items > 0 {
            (completed_items * 100) / total_items
        } else {
            0
        } as i32;

        let expected_progress = 30; // Mock expectation for now, can be dynamic later
        let status = if progress < expected_progress - 10 {
            "Lagging".to_string()
        } else if progress > expected_progress + 10 {
            "Overfast".to_string()
        } else {
            "On Track".to_string()
        };

        let credits = if s.name.len() % 2 == 0 { 4 } else { 3 }; // Existing logic

        courses.push(StudentCourse {
            id: s.id,
            name: s.name,
            faculty_name: s.resolved_faculty_name.unwrap_or("TBA".to_string()),
            credits,
            progress,
            subject_type: s.subject_type,
            faculty_email: s.faculty_email,
            faculty_phone: s.faculty_phone,
            faculty_department: s.faculty_department,
            status: Some(status),
        });
    }

    Ok(Json(courses))
}

// --- Lesson Plan ---

pub async fn get_student_lesson_plan_handler(
    State(state): State<AppState>,
    Query(params): Query<LessonPlanQuery>,
) -> Result<Json<LessonPlanResponse>, (StatusCode, Json<serde_json::Value>)> {
    println!("DEBUG: Request for subject_id: {}", params.subject_id);
    let subject_id = params.subject_id.trim();

    // Determine section
    let section = if let Some(s) = &params.section {
         s.clone()
    } else if let Some(uid_str) = &params.user_id {
         let section_opt: Option<String> = sqlx::query_scalar("SELECT section FROM users WHERE id = $1")
             .bind(Uuid::parse_str(uid_str).unwrap_or_default())
             .fetch_optional(&state.pool).await.unwrap_or(None);
         section_opt.unwrap_or_else(|| "Section A".to_string())
    } else {
         "Section A".to_string()
    };

    // Determine branch
    let branch_norm = if let Some(b) = &params.branch {
        Some(normalize_branch(b))
    } else if let Some(uid_str) = &params.user_id {
         let branch_opt: Option<String> = sqlx::query_scalar("SELECT branch FROM users WHERE id = $1")
             .bind(Uuid::parse_str(uid_str).unwrap_or_default())
             .fetch_optional(&state.pool).await.unwrap_or(None);
         branch_opt.map(|b| normalize_branch(&b))
    } else {
         None
    };

    let items = sqlx::query_as::<Postgres, LessonPlanItemResponse>(
        r#"
        SELECT 
            lpi.id::TEXT as id, 
            lpi.type, 
            lpi.topic, 
            lpi.text, 
            lpi.sno, 
            COALESCE(lpp.completed, FALSE) as completed,
            lpp.completed_date as completed_at,
            lpi.student_review,
            ls.schedule_date as scheduled_date
        FROM lesson_plan_items lpi
        LEFT JOIN lesson_plan_progress lpp ON lpi.id = lpp.item_id AND (TRIM(lpp.section) = TRIM($2) OR $2 IS NULL)
        LEFT JOIN lesson_schedule ls ON lpi.id = ls.topic_id 
            AND (TRIM(ls.section) = TRIM($2) OR $2 IS NULL)
            AND (ls.branch = $3 OR $3 IS NULL)
        WHERE TRIM(lpi.subject_id) ILIKE TRIM($1)
        ORDER BY lpi.order_index ASC
        "#
    )
    .bind(subject_id)
    .bind(section)
    .bind(branch_norm)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        eprintln!("Lesson Plan Query Error: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()})))
    })?;

    println!("DEBUG: Found {} items for subject {}", items.len(), subject_id);

    let total = items.len();
    let completed = items.iter().filter(|i| i.completed.unwrap_or(false)).count();
    let percentage = if total > 0 { (completed * 100) / total } else { 0 } as i32;
    
    let expected = 30; // Mock
    let status = if percentage < expected - 10 {
        "LAGGING".to_string()
    } else if percentage > expected + 10 {
        "OVERFAST".to_string()
    } else {
        "NORMAL".to_string()
    };

    Ok(Json(LessonPlanResponse {
        percentage,
        status,
        warning: if percentage < expected - 10 { Some("You are lagging behind schedule.".to_string()) } else { None },
        items,
    }))
}

pub async fn submit_lesson_plan_feedback_handler(
    State(state): State<AppState>,
    Json(payload): Json<LessonPlanFeedbackRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    
    let res = sqlx::query(
        "INSERT INTO lesson_plan_feedback (lesson_plan_item_id, user_id, rating, issue_type, comment) 
         VALUES ($1, $2, $3, $4, $5)"
    )
    .bind(&payload.lesson_plan_id)
    .bind(payload.user_id)
    .bind(payload.rating)
    .bind(&payload.issue_type)
    .bind(&payload.comment)
    .execute(&state.pool)
    .await;

    match res {
        Ok(_) => Ok(StatusCode::OK),
        Err(e) => {
            eprintln!("Submit Feedback Error: {:?}", e);
            Err((StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to submit feedback"}))))
        }
    }
}

pub async fn delete_lesson_plan_feedback_handler(
    State(state): State<AppState>,
    Path(feedback_id): Path<Uuid>,
    Query(params): Query<DeleteFeedbackQuery>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    
    let feedback = sqlx::query("SELECT user_id, created_at FROM lesson_plan_feedback WHERE id = $1")
        .bind(feedback_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "DB Error"}))))?;

    if let Some(row) = feedback {
         let owner_id: Uuid = row.get("user_id");
         let created_at: DateTime<Utc> = row.get("created_at");
         
         if owner_id != params.user_id {
              return Err((StatusCode::FORBIDDEN, Json(serde_json::json!({"error": "Not authorized"}))));
         }
         
         let diff = Utc::now().signed_duration_since(created_at);
         if diff.num_hours() > 24 {
              return Err((StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Cannot delete feedback after 24 hours"}))));
         }

         sqlx::query("DELETE FROM lesson_plan_feedback WHERE id = $1")
             .bind(feedback_id)
             .execute(&state.pool)
             .await
             .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to delete"}))))?;
             
         Ok(StatusCode::OK)
    } else {
         Err((StatusCode::NOT_FOUND, Json(serde_json::json!({"error": "Feedback not found"}))))
    }
}

pub async fn get_lesson_plan_feedback_handler(
    State(state): State<AppState>,
    Query(params): Query<GetFeedbackQuery>,
) -> Result<Json<Vec<LessonPlanFeedbackResponse>>, (StatusCode, Json<serde_json::Value>)> {
    
    let feedbacks = sqlx::query_as::<Postgres, LessonPlanFeedbackResponse>(
        r#"
        SELECT 
            lpf.id, lpf.user_id, lpf.rating, lpf.issue_type, lpf.comment, lpf.created_at,
            lpf.reply, lpf.replied_at,
            COALESCE(u.full_name, 'Unknown Student') as student_name
        FROM lesson_plan_feedback lpf
        LEFT JOIN users u ON lpf.user_id = u.id
        WHERE lpf.lesson_plan_item_id = $1
        ORDER BY lpf.created_at DESC
        "#
    )
    .bind(&params.lesson_plan_id)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        eprintln!("Get Feedback Error: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to fetch feedback"})))
    })?;

    Ok(Json(feedbacks))
}

pub async fn get_student_all_feedbacks_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<Vec<StudentFeedbacksResponse>>, (StatusCode, Json<serde_json::Value>)> {
    let user_uuid = resolve_user_id(&params.user_id, "Student", &state.pool).await?;

    let feedbacks = sqlx::query_as::<Postgres, StudentFeedbacksResponse>(
        r#"
        SELECT 
            lpf.id, lpf.rating, lpf.issue_type, lpf.comment, lpf.created_at, lpf.reply, lpf.replied_at,
            lpi.topic,
            s.id as subject_code,
            s.name as subject_name
        FROM lesson_plan_feedback lpf
        LEFT JOIN lesson_plan_items lpi ON lpf.lesson_plan_item_id = lpi.id
        LEFT JOIN subjects s ON lpi.subject_id = s.id::text
        WHERE lpf.user_id = $1
        ORDER BY lpf.created_at DESC
        "#
    )
    .bind(user_uuid)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        eprintln!("Get All Feedbacks Error: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to fetch feedbacks"})))
    })?;

    Ok(Json(feedbacks))
}

// Issues moved to routes/issue.rs

// --- Attendance ---

pub async fn get_student_attendance_handler(
    State(state): State<AppState>,
    Query(params): Query<AttendanceQuery>,
) -> Result<Json<AttendanceSummary>, StatusCode> {
    
    let student_uuid = if let Ok(uuid) = Uuid::parse_str(&params.student_id) {
        uuid
    } else {
        sqlx::query_scalar("SELECT id FROM users WHERE login_id = $1")
            .bind(&params.student_id.trim())
            .fetch_optional(&state.pool)
            .await
            .map_err(|e| {
                eprintln!("User Lookup Error: {:?}", e);
                StatusCode::INTERNAL_SERVER_ERROR
            })?
            .ok_or(StatusCode::BAD_REQUEST)?
    };

    let history = sqlx::query_as::<Postgres, AttendanceRecord>(
        r#"
        SELECT id, date, status, session
        FROM attendance
        WHERE student_uuid = $1
        ORDER BY date DESC, session ASC
        "#
    )
    .bind(student_uuid)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        eprintln!("Attendance History Error: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    let present_count = history.iter().filter(|r| r.status == "P" || r.status == "PRESENT").count() as i64;
    let absent_count = history.iter().filter(|r| r.status == "A" || r.status == "ABSENT").count() as i64;
    let total_classes = present_count + absent_count; // Exclude HOLIDAY
    
    let percentage = if total_classes > 0 {
        (present_count as f64 / total_classes as f64) * 100.0
    } else {
        0.0
    };

    Ok(Json(AttendanceSummary {
        total_classes,
        present_count,
        absent_count,
        percentage,
        history,
    }))
}

pub async fn request_attendance_correction_handler(
    State(state): State<AppState>,
    Json(payload): Json<AttendanceCorrectionRequestData>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let user_uuid = if let Ok(uuid) = Uuid::parse_str(&payload.user_id) {
        uuid
    } else {
        sqlx::query_scalar("SELECT id FROM users WHERE login_id = $1")
            .bind(&payload.user_id)
            .fetch_optional(&state.pool)
            .await
            .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Database Error"}))))?
            .ok_or((StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid User ID"}))))?
    };

    let user_row: (String, String, Option<String>) = sqlx::query_as("SELECT full_name, login_id, branch FROM users WHERE id = $1")
        .bind(user_uuid)
        .fetch_one(&state.pool)
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "User not found"}))))?;

    let (full_name, _login_id, branch) = user_row;
    let branch = branch.unwrap_or_else(|| "General".to_string());

    let dates_json = serde_json::to_value(&payload.items).expect("Failed to serialize items");

    let request_id = sqlx::query_scalar::<_, Uuid>(
        "INSERT INTO attendance_correction_requests (user_id, dates, reason, status, created_at)
         VALUES ($1, $2, $3, 'PENDING', NOW()) RETURNING id"
    )
    .bind(user_uuid)
    .bind(dates_json)
    .bind(&payload.reason)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": format!("DB Error: {}", e)}))))?;

    let msg = format!("{} attendance correction request", full_name);

    sqlx::query("INSERT INTO notifications (type, message, sender_id, recipient_id, branch, status, created_at) VALUES ($1, $2, $3, NULL, $4, 'PENDING', NOW())")
        .bind("ATTENDANCE_CORRECTION_REQUEST")
        .bind(msg)
        .bind(user_uuid.to_string())
        .bind(&branch)
        .execute(&state.pool)
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to send notification"}))))?;

    Ok(Json(serde_json::json!({"message": "Request submitted", "requestId": request_id})))
}

pub async fn get_attendance_correction_requests_handler(
    State(state): State<AppState>,
    Query(params): Query<HashMap<String, String>>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let student_id_str = params.get("studentId").ok_or((StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Missing studentId"}))))?;
    
    let student_uuid = if let Ok(uuid) = Uuid::parse_str(student_id_str) {
        uuid
    } else {
        sqlx::query_scalar("SELECT id FROM users WHERE LOWER(login_id) = LOWER($1)")
            .bind(student_id_str)
            .fetch_optional(&state.pool)
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?
            .ok_or((StatusCode::NOT_FOUND, Json(serde_json::json!({"error": "User not found"}))))?
    };

    let requests: Vec<CorrectionRequestHistoryItem> = sqlx::query_as(
        "SELECT id, dates, reason, status, created_at FROM attendance_correction_requests WHERE user_id = $1 ORDER BY created_at DESC"
    )
    .bind(student_uuid)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?;

    Ok(Json(serde_json::json!(requests)))
}

pub async fn delete_attendance_correction_requests_handler(
    State(state): State<AppState>,
    Json(payload): Json<DeleteCorrectionRequestsRequest>,
) -> Result<StatusCode, StatusCode> {
    sqlx::query("DELETE FROM attendance_correction_requests WHERE id = ANY($1)")
        .bind(&payload.ids)
        .execute(&state.pool)
        .await
        .map_err(|e| {
            eprintln!("Delete Request Error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;
    
    Ok(StatusCode::OK)
}

// --- Academics ---

#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SubjectMarkResponse {
    pub subject_id: String,
    pub subject_name: String,
    pub marks: Option<i32>,
    pub credit: i32,
    pub grade: Option<String>,
    pub grade_points: Option<i32>,
}

#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SemesterAcademicsResponse {
    pub semester_name: String,
    pub year_label: String,
    pub is_ongoing: bool,
    pub subjects: Vec<SubjectMarkResponse>,
    pub sgpa: Option<f64>,
}

pub async fn get_student_academics_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<Vec<SemesterAcademicsResponse>>, (StatusCode, Json<serde_json::Value>)> {
    let user_uuid = resolve_user_id(&params.user_id, "Student", &state.pool).await?;

    // Fetch user details
    #[derive(sqlx::FromRow)]
    struct UserDataInfo {
        login_id: String,
        branch: Option<String>,
        year: Option<String>,
        semester: Option<String>,
    }

    let user_opt = sqlx::query_as::<_, UserDataInfo>("SELECT login_id, branch, year, semester FROM users WHERE id = $1")
        .bind(user_uuid)
        .fetch_optional(&state.pool)
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "DB Error"}))))?;

    let user = match user_opt {
        Some(u) => u,
        None => return Err((StatusCode::NOT_FOUND, Json(serde_json::json!({"error": "User not found"})))),
    };

    let branch_norm = normalize_branch(&user.branch.unwrap_or_default());
    let year_str = user.year.unwrap_or_default();
    let sem_str = user.semester.unwrap_or_default();

    let semester_key = if year_str == "1st Year" {
        "1st Year".to_string()
    } else if !sem_str.is_empty() {
        sem_str
    } else {
        if year_str.contains("2nd Year") || year_str.contains("3rd Semester") { "3rd Semester".to_string() }
        else if year_str.contains("4th Semester") { "4th Semester".to_string() }
        else if year_str.contains("3rd Year") || year_str.contains("5th Semester") { "5th Semester".to_string() }
        else if year_str.contains("6th Semester") { "6th Semester".to_string() }
        else { "1st Year".to_string() }
    };

    let ordered_sems = vec![
        ("1st Year", "1st Year", "Semester 1"),
        ("2nd Year", "3rd Semester", "Semester 3"),
        ("2nd Year", "4th Semester", "Semester 4"),
        ("3rd Year", "5th Semester", "Semester 5"),
        ("3rd Year", "6th Semester", "Semester 6"),
    ];

    let mut result = Vec::new();

    // Loop through semesters until we find the current one
    for (year_l, db_sem, disp_sem) in ordered_sems {
        let is_current = db_sem == semester_key;
        
        // Fetch subjects for this branch and sem
        #[derive(sqlx::FromRow)]
        struct SubjData {
            id: String,
            name: String,
            credit: Option<i32>,
        }
        let subjects: Vec<SubjData> = sqlx::query_as(
            "SELECT id, name, credit FROM subjects WHERE branch = $1 AND semester = $2 ORDER BY id ASC"
        )
        .bind(&branch_norm)
        .bind(db_sem)
        .fetch_all(&state.pool)
        .await
        .unwrap_or_default();

        let mut sub_responses = Vec::new();
        let mut total_points = 0.0;
        let mut total_credits = 0.0;
        let mut all_marks_present = true;

        for s in &subjects {
            let credit_val = s.credit.unwrap_or(3);
            
            // Fetch mark
            let mark_opt: Option<i32> = sqlx::query_scalar(
                "SELECT marks FROM student_marks WHERE student_id = $1 AND semester = $2 AND subject_name = $3"
            )
            .bind(&user.login_id)
            .bind(db_sem)
            .bind(&s.name)
            .fetch_optional(&state.pool)
            .await
            .unwrap_or(None)
            .flatten();

            let (grade, gpa) = if let Some(m) = mark_opt {
                if m >= 90 { (Some("O".to_string()), Some(10)) }
                else if m >= 80 { (Some("A+".to_string()), Some(9)) }
                else if m >= 70 { (Some("A".to_string()), Some(8)) }
                else if m >= 60 { (Some("B+".to_string()), Some(7)) }
                else if m >= 50 { (Some("B".to_string()), Some(6)) }
                else if m >= 40 { (Some("C".to_string()), Some(5)) }
                else { (Some("F".to_string()), Some(0)) }
            } else {
                all_marks_present = false;
                (None, None)
            };

            if let Some(gp) = gpa {
                total_points += (gp * credit_val) as f64;
                total_credits += credit_val as f64;
            }

            sub_responses.push(SubjectMarkResponse {
                subject_id: s.id.clone(),
                subject_name: s.name.clone(),
                marks: mark_opt,
                credit: credit_val,
                grade,
                grade_points: gpa,
            });
        }

        let sgpa = if !subjects.is_empty() && all_marks_present && total_credits > 0.0 {
            Some(total_points / total_credits)
        } else {
            None
        };

        result.push(SemesterAcademicsResponse {
            year_label: year_l.to_string(),
            semester_name: disp_sem.to_string(),
            is_ongoing: is_current,
            subjects: sub_responses,
            sgpa,
        });

        if is_current {
            break;
        }
    }

    Ok(Json(result))
}

