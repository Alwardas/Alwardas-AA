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

// --- Profile ---

pub async fn get_student_profile_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<StudentProfileResponse>, StatusCode> {
    let user_profile = sqlx::query_as::<Postgres, StudentProfileResponse>(
        "SELECT 
            u.full_name, u.login_id, u.branch, u.year, u.semester, u.dob, u.batch_no, u.section,
            EXISTS(SELECT 1 FROM profile_update_requests WHERE user_id = u.id AND status = 'PENDING') as pending_update
         FROM users u WHERE u.id = $1"
    )
    .bind(params.user_id)
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

    let user_opt = sqlx::query_as::<_, UserData>("SELECT branch, year, semester, section FROM users WHERE id = $1")
        .bind(params.user_id)
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

    #[derive(sqlx::FromRow)]
    struct SubjectData {
        id: String,
        name: String,
        subject_type: String,
        resolved_faculty_name: Option<String>,
    }

    let subjects = sqlx::query_as::<_, SubjectData>(
        r#"
        SELECT 
            s.id, 
            s.name, 
            s.type as subject_type,
            COALESCE(u.full_name, s.faculty_name, 'TBA') as resolved_faculty_name
        FROM subjects s
        LEFT JOIN faculty_subjects fs ON s.id = fs.subject_id AND fs.branch = s.branch AND fs.status = 'APPROVED' AND fs.section = $3
        LEFT JOIN users u ON fs.user_id = u.id
        WHERE s.branch = $1 AND s.semester = $2
        "#
    )
    .bind(&branch_norm)
    .bind(semester_key)
    .bind(section)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        eprintln!("Error fetching subjects: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    let courses: Vec<StudentCourse> = subjects.into_iter().enumerate().map(|(i, s)| {
        let progress = ((s.name.len() * 7 + i * 13) % 70 + 30) as i32;
        let credits = if s.name.len() % 2 == 0 { 4 } else { 3 };
        
        StudentCourse {
            id: s.id,
            name: s.name,
            faculty_name: s.resolved_faculty_name.unwrap_or("TBA".to_string()),
            credits,
            progress,
            subject_type: s.subject_type,
        }
    }).collect();

    Ok(Json(courses))
}

// --- Lesson Plan ---

pub async fn get_student_lesson_plan_handler(
    State(state): State<AppState>,
    Query(params): Query<LessonPlanQuery>,
) -> Result<Json<LessonPlanResponse>, StatusCode> {
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
            lpi.student_review
        FROM lesson_plan_items lpi
        LEFT JOIN lesson_plan_progress lpp ON lpi.id = lpp.item_id AND lpp.section = $2
        WHERE lpi.subject_id = $1 
        ORDER BY lpi.order_index ASC
        "#
    )
    .bind(subject_id)
    .bind(section)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        eprintln!("Lesson Plan Query Error: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
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
         if diff.num_minutes() > 15 {
              return Err((StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Cannot delete feedback after 15 minutes"}))));
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

// --- Issues ---

pub async fn submit_issue_handler(
    State(state): State<AppState>,
    Json(payload): Json<SubmitIssueRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let uid = Uuid::parse_str(&payload.user_id).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid User ID"}))))?;

    sqlx::query("INSERT INTO issues (user_id, subject, description) VALUES ($1, $2, $3)")
        .bind(uid)
        .bind(&payload.subject)
        .bind(&payload.description)
        .execute(&state.pool)
        .await
        .map_err(|e| {
            eprintln!("Submit Issue Error: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to submit issue"})))
        })?;

    Ok(StatusCode::OK)
}

pub async fn get_student_issues_handler(
    State(state): State<AppState>,
    Query(params): Query<GetIssuesQuery>,
) -> Result<Json<Vec<Issue>>, (StatusCode, Json<serde_json::Value>)> {
    let uid = Uuid::parse_str(&params.user_id).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid User ID"}))))?;

    let query = r#"
        SELECT 
            i.id, i.user_id, i.subject, i.description, i.status, i.response, i.responded_by, i.created_at, i.reacted_at,
            u_responder.full_name as responder_name
        FROM issues i
        LEFT JOIN users u_responder ON i.responded_by = u_responder.id
        WHERE i.user_id = $1
        ORDER BY i.created_at DESC
    "#;

    let issues = sqlx::query_as::<Postgres, Issue>(query)
        .bind(uid)
        .fetch_all(&state.pool)
        .await
        .map_err(|e| {
            eprintln!("Get Issues Error: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to fetch issues"})))
        })?;

    Ok(Json(issues))
}

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

    let total_classes = history.len() as i64; 
    let present_count = history.iter().filter(|r| r.status == "P").count() as i64;
    let absent_count = history.iter().filter(|r| r.status == "A").count() as i64;
    
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
