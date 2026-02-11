use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
use sqlx::{Postgres, Row, QueryBuilder};
use crate::models::{DepartmentTiming, *};
use uuid::Uuid;
use chrono::Utc;

use std::collections::HashMap;

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MoveStudentsRequest {
    pub student_ids: Vec<String>,
    pub target_section: String,
    pub branch: String, 
    pub year: String,
}


// --- Faculty Profile ---

pub async fn get_faculty_profile_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<FacultyProfileResponse>, StatusCode> {
    let profile = sqlx::query_as::<Postgres, FacultyProfileResponse>(
        "SELECT full_name, login_id as faculty_id, branch, email, phone_number, experience, dob FROM users WHERE id = $1"
    )
    .bind(params.user_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| {
         eprintln!("Faculty Profile Fetch Error: {:?}", e);
         StatusCode::INTERNAL_SERVER_ERROR
    })?;

    match profile {
        Some(p) => Ok(Json(p)),
        None => Err(StatusCode::NOT_FOUND),
    }
}

// --- Faculty Subjects ---

pub async fn get_faculty_subjects_handler(
    State(state): State<AppState>,
    Query(params): Query<FacultyQueryParams>,
) -> Result<Json<Vec<FacultySubjectResponse>>, StatusCode> {
    let subjects = sqlx::query_as::<Postgres, FacultySubjectResponse>(
        r#"
        SELECT 
            s.id, 
            s.name, 
            s.branch, 
            s.semester, 
            fs.status,
            fs.subject_id,
            fs.section,
            COALESCE(
                (
                    SELECT CASE 
                        WHEN COUNT(*) = 0 THEN 0 
                        ELSE (COUNT(CASE WHEN lpp.completed = TRUE THEN 1 END) * 100 / COUNT(*))
                    END
                    FROM lesson_plan_items lpi 
                    LEFT JOIN lesson_plan_progress lpp ON lpi.id = lpp.item_id AND lpp.section = fs.section
                    WHERE lpi.subject_id = s.id
                ), 0
            )::INTEGER as completion_percentage
        FROM faculty_subjects fs
        JOIN subjects s ON fs.subject_id = s.id
        WHERE fs.user_id = $1
        "#
    )
    .bind(params.user_id)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        eprintln!("Fetch Faculty Subjects Error: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    Ok(Json(subjects))
}

pub async fn add_faculty_subject_handler(
    State(state): State<AppState>,
    Json(payload): Json<AddFacultySubjectRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let section = payload.section.unwrap_or_else(|| "Section A".to_string());

    sqlx::query(
        r#"
        INSERT INTO faculty_subjects (user_id, subject_id, subject_name, branch, status, section)
        VALUES ($1, $2, $3, $4, 'PENDING', $5) 
        ON CONFLICT (user_id, subject_id, section) 
        DO UPDATE SET status = 'PENDING' 
        WHERE faculty_subjects.status != 'APPROVED'
        "#
    )
    .bind(payload.user_id)
    .bind(&payload.subject_id)
    .bind(&payload.subject_name)
    .bind(&payload.branch)
    .bind(section)
    .execute(&state.pool)
    .await
    .map_err(|e| {
         eprintln!("Add Subject Error: {:?}", e);
         (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to add subject"})))
    })?;

    let msg = format!("Faculty requested subject: {}", payload.subject_name);
    let _ = sqlx::query(
        "INSERT INTO notifications (type, message, sender_id, branch, status, created_at) VALUES ($1, $2, $3, $4, 'UNREAD', NOW())"
    )
    .bind("SUBJECT_APPROVAL")
    .bind(msg)
    .bind(payload.user_id.to_string())
    .bind(&payload.branch)
    .execute(&state.pool)
    .await;

    Ok(StatusCode::OK)
}

pub async fn remove_faculty_subject_handler(
    State(state): State<AppState>,
    Json(payload): Json<RemoveFacultySubjectRequest>,
) -> Result<StatusCode, StatusCode> {
    let section = payload.section.unwrap_or_else(|| "Section A".to_string());
    sqlx::query("DELETE FROM faculty_subjects WHERE user_id = $1 AND subject_id = $2 AND section = $3")
        .bind(payload.user_id)
        .bind(payload.subject_id)
        .bind(section)
        .execute(&state.pool)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        
    Ok(StatusCode::OK)
}

// --- Lesson Plan ---

pub async fn mark_lesson_plan_complete_handler(
    State(state): State<AppState>,
    Json(payload): Json<MarkCompleteRequest>,
) -> Result<StatusCode, StatusCode> {
    let now = if payload.completed { Some(Utc::now()) } else { None };
    let item_uuid = Uuid::parse_str(&payload.item_id).map_err(|_| StatusCode::BAD_REQUEST)?;
    let section = payload.section.unwrap_or_else(|| "Section A".to_string());

    let _ = sqlx::query("INSERT INTO lesson_plan_progress (item_id, section, completed, completed_date) VALUES ($1, $2, $3, $4) ON CONFLICT (item_id, section) DO UPDATE SET completed = EXCLUDED.completed, completed_date = EXCLUDED.completed_date")
        .bind(item_uuid)
        .bind(section)
        .bind(payload.completed)
        .bind(now)
        .execute(&state.pool)
        .await
        .map_err(|e| {
            eprintln!("Mark Complete Error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    Ok(StatusCode::OK)
}

pub async fn reply_to_feedback_handler(
    State(state): State<AppState>,
    Json(payload): Json<ReplyFeedbackRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let update_res = sqlx::query(
        "UPDATE lesson_plan_feedback SET reply = $1, replied_at = NOW(), replied_by = $2 WHERE id = $3 RETURNING user_id"
    )
    .bind(&payload.reply)
    .bind(payload.faculty_id)
    .bind(payload.feedback_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| {
         eprintln!("Reply Update Error: {:?}", e);
         (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to save reply"})))
    })?;

    if let Some(row) = update_res {
         let student_id: Uuid = row.get("user_id");
         let msg = "Faculty replied to your comment.";
         let _ = sqlx::query(
            "INSERT INTO notifications (type, message, sender_id, recipient_id, status, created_at) VALUES ($1, $2, $3, $4, 'UNREAD', NOW())"
         )
         .bind("COMMENT_REPLY")
         .bind(msg)
         .bind(payload.faculty_id.to_string())
         .bind(student_id.to_string())
         .execute(&state.pool)
         .await;
         
         Ok(StatusCode::OK)
    } else {
         Err((StatusCode::NOT_FOUND, Json(serde_json::json!({"error": "Feedback not found"}))))
    }
}

// --- Students View ---

pub async fn get_students_handler(
    State(state): State<AppState>,
    Query(params): Query<StudentsQuery>,
) -> Result<Json<Vec<StudentBasicInfo>>, StatusCode> {
    let branch_variations = get_branch_variations(&params.branch);
    let year_pattern = format!("{}%", params.year.trim());
    let section_filter = params.section.clone().unwrap_or_else(|| "Section A".to_string());

    let students = sqlx::query_as::<Postgres, StudentBasicInfo>(
        "SELECT login_id as student_id, full_name, branch, year, section FROM users WHERE role = 'Student' AND branch = ANY($1::text[]) AND year LIKE $2 AND section = $3 AND is_approved = true ORDER BY login_id ASC"
    )
    .bind(branch_variations)
    .bind(year_pattern)
    .bind(section_filter)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        eprintln!("Fetch Students Error: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    Ok(Json(students))
}

pub async fn get_faculty_by_branch_handler(
    State(state): State<AppState>,
    Query(params): Query<FacultyByBranchQuery>,
) -> Result<Json<Vec<FacultyListDTO>>, StatusCode> {
    let mut query_builder = QueryBuilder::new(
        "SELECT id, full_name, login_id, email, phone_number, experience, branch, role FROM users WHERE role IN ('Faculty', 'HOD')"
    );

    if let Some(branch) = &params.branch {
        if branch != "All" && !branch.is_empty() {
            let normalized = normalize_branch(branch);
            query_builder.push(" AND branch = ");
            query_builder.push_bind(normalized);
        }
    }

    query_builder.push(" ORDER BY CASE WHEN role = 'HOD' THEN 0 ELSE 1 END, full_name ASC");

    let faculty_list = query_builder.build_query_as::<FacultyListDTO>()
        .fetch_all(&state.pool)
        .await
        .map_err(|e| {
            eprintln!("Fetch Faculty Error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    Ok(Json(faculty_list))
}

pub async fn move_students_handler(
    State(state): State<AppState>,
    Json(payload): Json<MoveStudentsRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    println!("DEBUG: Moving students {:?} to Section {}", payload.student_ids, payload.target_section);

    let mut tx = state.pool.begin().await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?;

    // We assume 'studentIds' are 'studentId' (login_id). 
    // If they are UUIDs, handle accordingly. Frontend sends 'pin' or 'studentId', which is login_id.
    
    // Using login_id because frontend sends that.
    let query = "UPDATE users SET section = $1 WHERE login_id = ANY($2)";
    
    let result = sqlx::query(query)
        .bind(&payload.target_section)
        .bind(&payload.student_ids)
        .execute(&mut *tx)
        .await
        .map_err(|e| {
             eprintln!("Move Students Error: {:?}", e);
             (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to update sections"})))
        })?;

    tx.commit().await
        .map_err(|_e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Commit Failed"}))))?;

    println!("✅ Moved {} students to {}", result.rows_affected(), payload.target_section);

    Ok(StatusCode::OK)
}

// --- Attendance ---

pub async fn submit_attendance_handler(
    State(state): State<AppState>,
    Json(payload): Json<SubmitAttendanceRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let pool = state.pool.clone();
    
    let student_uuid = resolve_user_id(&payload.student_id, "Student", &pool).await?;
    let faculty_uuid = resolve_user_id(&payload.faculty_id, "Faculty", &pool).await?;
    
    let date_str = payload.date.split('T').next().unwrap_or(&payload.date);
    let date = chrono::NaiveDate::parse_from_str(date_str, "%Y-%m-%d")
         .map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": format!("Invalid Date format, got: {}", payload.date)}))))?;

    // Added 'section' to selection
    let student_row = sqlx::query("SELECT login_id, full_name, branch, year, section FROM users WHERE id = $1")
        .bind(student_uuid)
        .fetch_one(&state.pool)
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to fetch student details"}))))?;

    let faculty_name: String = sqlx::query_scalar("SELECT full_name FROM users WHERE id = $1")
        .bind(faculty_uuid)
        .fetch_one(&state.pool)
        .await
        .unwrap_or_else(|_| "Unknown Faculty".to_string());

    let s_login: String = student_row.get("login_id");
    let s_name: String = student_row.get("full_name");
    let s_branch: Option<String> = student_row.get("branch");
    let s_year: Option<String> = student_row.get("year");
    let s_section: Option<String> = student_row.get("section"); // Get section
    
    let session = payload.session.clone().unwrap_or_else(|| "MORNING".to_string());
    let db_status = if payload.status.to_uppercase().starts_with('P') { "P" } else { "A" };

    // Added 'section' to INSERT
    sqlx::query("INSERT INTO attendance (student_uuid, faculty_uuid, date, status, branch, year, session, section, student_name, student_login_id, faculty_name) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)")
        .bind(student_uuid)
        .bind(faculty_uuid)
        .bind(date)
        .bind(db_status)
        .bind(s_branch.clone().unwrap_or_default())
        .bind(s_year.unwrap_or_default())
        .bind(&session)
        .bind(s_section.unwrap_or_else(|| "Section A".to_string())) // Bind section
        .bind(s_name)
        .bind(s_login)
        .bind(faculty_name)
        .execute(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": format!("Database Error: {}", e)}))))?;

    let formatted_date = date.format("%d-%m-%Y").to_string();
    let status_text = if db_status == "P" { "Present" } else { "Absent" };
    let msg = format!("{} {} session marked as {}", formatted_date, session, status_text);
    
    let _ = sqlx::query("INSERT INTO notifications (type, message, sender_id, recipient_id, branch, status, created_at) VALUES ($1, $2, $3, $4, $5, 'UNREAD', NOW())")
        .bind("ATTENDANCE")
        .bind(&msg)
        .bind(&payload.faculty_id) 
        .bind(student_uuid.to_string())
        .bind(s_branch.unwrap_or_default())
        .execute(&state.pool)
        .await;

    Ok(StatusCode::OK)
}

pub async fn submit_attendance_batch_handler(
    State(state): State<AppState>,
    Json(payload): Json<BatchAttendanceRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let faculty_id_str = payload.marked_by.clone();
    
    let faculty_row = sqlx::query("SELECT id, full_name FROM users WHERE login_id = $1")
        .bind(&faculty_id_str)
        .fetch_optional(&state.pool)
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "DB Error resolving faculty"}))))?;
    
    let (faculty_uuid, faculty_name) = match faculty_row {
        Some(row) => (row.get::<Uuid, _>("id"), row.get::<String, _>("full_name")),
        None => return Err((StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": format!("Invalid Faculty ID: {}", faculty_id_str)}))))
    };

    let date_str = payload.date.split('T').next().unwrap_or(&payload.date);
    let date = chrono::NaiveDate::parse_from_str(date_str, "%Y-%m-%d")
         .map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid Date format"}))))?;

    let session = payload.session.unwrap_or_else(|| "MORNING".to_string()).to_uppercase();
    let student_login_ids: Vec<String> = payload.records.iter().map(|r| r.student_id.clone()).collect();

    #[derive(sqlx::FromRow, Clone)]
    struct StudentInfoLocal {
        id: Uuid,
        login_id: String,
        full_name: String,
        branch: Option<String>,
        year: Option<String>,
        section: Option<String>,
    }

    let rows = sqlx::query_as::<_, StudentInfoLocal>("SELECT id, login_id, full_name, branch, year, section FROM users WHERE login_id = ANY($1) OR id::text = ANY($1)")
        .bind(&student_login_ids)
        .fetch_all(&state.pool)
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Database error resolving students"}))))?;

    let mut student_map: HashMap<String, StudentInfoLocal> = HashMap::new();
    for row in rows {
        student_map.insert(row.login_id.clone(), row.clone());
        student_map.insert(row.id.to_string(), row);
    }

    let mut tx = state.pool.begin().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "DB Transaction Error"}))))?;
    
    // 1. Collect Valid Student UUIDs
    let mut uuids_to_update = Vec::new();
    for record in &payload.records {
        if let Some(info) = student_map.get(&record.student_id) {
            uuids_to_update.push(info.id);
        }
    }

    // 2. Clear existing records to handle updates/corrections
    if !uuids_to_update.is_empty() {
        sqlx::query("DELETE FROM attendance WHERE student_uuid = ANY($1) AND date = $2 AND session = $3")
            .bind(&uuids_to_update)
            .bind(date)
            .bind(&session)
            .execute(&mut *tx)
            .await
            .map_err(|e| {
                eprintln!("Clear Attendance Error: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to clear existing records"})))
            })?;
    }

    let mut count = 0;
    let mut errors = Vec::new();

    // 3. Insert Loop
    for record in payload.records {
        if let Some(info) = student_map.get(&record.student_id) {
            let db_status = if record.status.to_uppercase().starts_with('P') { "P" } else { "A" };

            sqlx::query("INSERT INTO attendance (student_uuid, faculty_uuid, date, status, branch, year, session, section, student_name, student_login_id, faculty_name) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)")
                .bind(info.id)
                .bind(faculty_uuid)
                .bind(date)
                .bind(db_status)
                .bind(info.branch.clone().unwrap_or_default())
                .bind(info.year.clone().unwrap_or_default())
                .bind(&session)
                .bind(info.section.clone().unwrap_or_else(|| "Section A".to_string()))
                .bind(&info.full_name)
                .bind(&info.login_id)
                .bind(&faculty_name)
                .execute(&mut *tx)
                .await.ok();

            // Notify only if needed (Optional: Logic to avoid spamming notification on update? Keep for now)
            let formatted_date = date.format("%d-%m-%Y").to_string();
            let status_text = if db_status == "P" { "Present" } else { "Absent" };
            let msg = format!("{} {} session updated to {}", formatted_date, session, status_text);
            
            sqlx::query("INSERT INTO notifications (type, message, sender_id, recipient_id, status, branch, created_at) VALUES ($1, $2, $3, $4, 'UNREAD', $5, NOW())")
                .bind("ATTENDANCE")
                .bind(msg)
                .bind(&faculty_id_str)
                .bind(info.id.to_string())
                .bind(info.branch.clone().unwrap_or_default())
                .execute(&mut *tx)
                .await.ok();
            
            count += 1;
        } else {
            errors.push(format!("Student ID not found: {}", record.student_id));
        }
    }

    tx.commit().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "DB Commit Error"}))))?;

    Ok(Json(serde_json::json!({"message": "Batch processed", "count": count, "errors": errors})))
}

pub async fn check_attendance_status_handler(
    State(state): State<AppState>,
    Query(params): Query<CheckAttendanceQuery>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let date_str = params.date.split('T').next().unwrap_or(&params.date);
    let date = chrono::NaiveDate::parse_from_str(date_str, "%Y-%m-%d").map_err(|_| StatusCode::BAD_REQUEST)?;
    let branch_variations = get_branch_variations(&params.branch);
    let section = params.section.clone().unwrap_or_else(|| "Section A".to_string());
    
    let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM attendance WHERE branch = ANY($1::text[]) AND year = $2 AND date = $3 AND session = $4 AND section = $5")
        .bind(branch_variations)
        .bind(params.year.trim())
        .bind(date)
        .bind(params.session.trim().to_uppercase())
        .bind(section)
        .fetch_one(&state.pool)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(serde_json::json!({"submitted": count > 0, "count": count})))
}

pub async fn get_class_attendance_record_handler(
    State(state): State<AppState>,
    Query(params): Query<ClassRecordQuery>,
) -> Result<Json<ClassRecordResponse>, StatusCode> {
    let date_str = params.date.split('T').next().unwrap_or(&params.date);
    let date = chrono::NaiveDate::parse_from_str(date_str, "%Y-%m-%d").map_err(|_| StatusCode::BAD_REQUEST)?;
    let session_upper = params.session.trim().to_uppercase();
    let branch_variations = get_branch_variations(&params.branch);
    let section = params.section.clone().unwrap_or_else(|| "Section A".to_string());
    
    let meta_row: Option<(String,)> = sqlx::query_as("SELECT faculty_name FROM attendance WHERE branch = ANY($1::text[]) AND year = $2 AND session = $3 AND date = $4 AND section = $5 LIMIT 1")
       .bind(&branch_variations)
       .bind(params.year.trim())
       .bind(&session_upper)
       .bind(date)
       .bind(&section)
       .fetch_optional(&state.pool)
       .await
       .map_err(|e| {
           eprintln!("Meta Row Error: {:?}", e);
           StatusCode::INTERNAL_SERVER_ERROR
       })?;
       
    if let Some((marked_by,)) = meta_row {
        let records = sqlx::query_as::<_, StudentAttendanceItem>(
            "SELECT u.login_id as student_id, u.full_name, CASE WHEN a.status = 'P' THEN 'PRESENT' ELSE 'ABSENT' END as status FROM attendance a JOIN users u ON a.student_uuid = u.id WHERE a.branch = ANY($1::text[]) AND a.year = $2 AND a.session = $3 AND a.date = $4 AND a.section = $5 ORDER BY u.login_id ASC"
        )
        .bind(&branch_variations)
        .bind(params.year.trim())
        .bind(&session_upper)
        .bind(date)
        .bind(section)
        .fetch_all(&state.pool)
        .await
        .map_err(|e| {
            eprintln!("Records Fetch Error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;
        
        Ok(Json(ClassRecordResponse { marked: true, marked_by: Some(marked_by), students: records }))
    } else {
        println!("DEBUG: Fallback fetching students for branch variations: {:?}, year: {}, section: {}", branch_variations, params.year, section);
        let year_pattern = format!("{}%", params.year.trim());
        let students = sqlx::query_as::<_, StudentAttendanceItem>(
            "SELECT login_id as student_id, full_name, 'PENDING' as status FROM users WHERE role = 'Student' AND branch = ANY($1::text[]) AND year LIKE $2 AND section = $3 AND is_approved = true ORDER BY login_id ASC"
        )
         .bind(&branch_variations)
         .bind(year_pattern)
         .bind(section)
         .fetch_all(&state.pool)
         .await
         .map_err(|e| {
            eprintln!("Fallback Students Fetch Error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
         })?;
         
         Ok(Json(ClassRecordResponse { marked: false, marked_by: None, students }))
    }
}

pub async fn get_attendance_stats_handler(
    State(state): State<AppState>,
    Query(params): Query<AttendanceStatsQuery>,
) -> Result<Json<AttendanceStatsResponse>, StatusCode> {
    let date_str = params.date.split('T').next().unwrap_or(&params.date);
    let date = chrono::NaiveDate::parse_from_str(date_str, "%Y-%m-%d").map_err(|_| StatusCode::BAD_REQUEST)?;
    let normalized = normalize_branch(&params.branch);
    
    // 1. Total Students
    let mut qb_users = sqlx::QueryBuilder::new("SELECT COUNT(*) FROM users WHERE role = 'Student' AND branch = ");
    qb_users.push_bind(&normalized);
    qb_users.push(" AND is_approved = true");
    
    if let Some(y) = &params.year {
        qb_users.push(" AND year = ");
        qb_users.push_bind(y);
    }
    if let Some(s) = &params.section {
        qb_users.push(" AND section = ");
        qb_users.push_bind(s);
    }
    
    let total_students: i64 = qb_users.build_query_scalar()
        .fetch_one(&state.pool)
        .await
        .unwrap_or(0);
    
    // 2. Present
    let mut qb_present = sqlx::QueryBuilder::new("SELECT COUNT(DISTINCT student_uuid) FROM attendance WHERE branch = ");
    qb_present.push_bind(&normalized);
    qb_present.push(" AND date = ");
    qb_present.push_bind(date);
    qb_present.push(" AND status = 'P'");

    if let Some(sess) = &params.session {
        let s_val = sess.trim().to_uppercase();
        if s_val != "ALL" && !s_val.is_empty() {
             qb_present.push(" AND session = ");
             qb_present.push_bind(s_val);
        }
    }
    if let Some(y) = &params.year {
        qb_present.push(" AND year = ");
        qb_present.push_bind(y);
    }
    if let Some(s) = &params.section {
        qb_present.push(" AND section = ");
        qb_present.push_bind(s);
    }

    let total_present: i64 = qb_present.build_query_scalar()
        .fetch_one(&state.pool)
        .await
        .unwrap_or(0);

    // 3. Absent
    let mut qb_absent = sqlx::QueryBuilder::new("SELECT COUNT(DISTINCT student_uuid) FROM attendance WHERE branch = ");
    qb_absent.push_bind(&normalized);
    qb_absent.push(" AND date = ");
    qb_absent.push_bind(date);
    qb_absent.push(" AND status = 'A'");

    if let Some(sess) = &params.session {
        let s_val = sess.trim().to_uppercase();
        if s_val != "ALL" && !s_val.is_empty() {
             qb_absent.push(" AND session = ");
             qb_absent.push_bind(s_val);
        }
    }
    if let Some(y) = &params.year {
        qb_absent.push(" AND year = ");
        qb_absent.push_bind(y);
    }
    if let Some(s) = &params.section {
        qb_absent.push(" AND section = ");
        qb_absent.push_bind(s);
    }

    let total_absent: i64 = qb_absent.build_query_scalar()
        .fetch_one(&state.pool)
        .await
        .unwrap_or(0);

    Ok(Json(AttendanceStatsResponse { total_students, total_present, total_absent }))
}

// --- HOD Actions ---

pub async fn approve_handler(
    State(state): State<AppState>,
    Json(payload): Json<ApprovalRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let is_approved = payload.action == "APPROVE";
    let mut tx = state.pool.begin().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to transaction"}))))?;

    if is_approved {
        sqlx::query("UPDATE users SET is_approved = TRUE WHERE login_id = $1").bind(&payload.sender_id).execute(&mut *tx).await.ok();
        sqlx::query("UPDATE notifications SET status = 'ACCEPTED' WHERE id = $1").bind(payload.request_id).execute(&mut *tx).await.ok();
    } else {
        sqlx::query("UPDATE notifications SET status = 'REJECTED' WHERE id = $1").bind(payload.request_id).execute(&mut *tx).await.ok();
    }
    tx.commit().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to commit"}))))?;
    Ok(StatusCode::OK)
}

pub async fn approve_subject_handler(
    State(state): State<AppState>,
    Json(payload): Json<ApproveSubjectRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let is_approved = payload.action == "APPROVE";
    let faculty_uuid = resolve_user_id(&payload.sender_id, "Faculty", &state.pool).await?;

    if is_approved {
        sqlx::query("UPDATE faculty_subjects SET status = 'APPROVED' WHERE user_id = $1 AND status = 'PENDING'").bind(faculty_uuid).execute(&state.pool).await.ok();
        sqlx::query("UPDATE notifications SET status = 'ACCEPTED' WHERE id = $1").bind(payload.notification_id).execute(&state.pool).await.ok();
    } else {
        sqlx::query("DELETE FROM faculty_subjects WHERE user_id = $1 AND status = 'PENDING'").bind(faculty_uuid).execute(&state.pool).await.ok();
        sqlx::query("UPDATE notifications SET status = 'REJECTED' WHERE id = $1").bind(payload.notification_id).execute(&state.pool).await.ok();
    }
    Ok(StatusCode::OK)
}

pub async fn approve_profile_change_handler(
    State(state): State<AppState>,
    Json(payload): Json<ApproveProfileChangeRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let is_approved = payload.action == "APPROVE";
    let user_uuid = resolve_user_id(&payload.sender_id, "User", &state.pool).await?;

    if is_approved {
        let row = sqlx::query("SELECT id, new_data FROM profile_update_requests WHERE user_id = $1 AND status = 'PENDING' ORDER BY created_at DESC LIMIT 1").bind(user_uuid).fetch_optional(&state.pool).await.ok().flatten();
        if let Some(r) = row {
             let request_id: Uuid = r.get("id");
             let new_data: serde_json::Value = r.get("new_data");
             let full_name = new_data["newFullName"].as_str().or(new_data["fullName"].as_str()).map(|s| s.to_string());
             let phone = new_data["phoneNumber"].as_str().map(|s| s.to_string());
             let email = new_data["email"].as_str().map(|s| s.to_string());
             let exp = new_data["experience"].as_str().map(|s| s.to_string());
             let dob_str = new_data["newDob"].as_str().or(new_data["dob"].as_str()).map(|s| s.to_string());
             let login_id = new_data["newStudentId"].as_str().or(new_data["facultyId"].as_str()).map(|s| s.to_string());
             let branch = new_data["newBranch"].as_str().or(new_data["branch"].as_str()).map(|s| s.to_string());
             let year = new_data["newYear"].as_str().or(new_data["year"].as_str()).map(|s| s.to_string());
             let semester = new_data["newSemester"].as_str().map(|s| s.to_string());
             let batch_no = new_data["newBatchNo"].as_str().map(|s| s.to_string());

             sqlx::query("UPDATE users SET full_name=COALESCE($1,full_name), phone_number=COALESCE($2,phone_number), email=COALESCE($3,email), experience=COALESCE($4,experience), dob=COALESCE($5::DATE,dob), login_id=COALESCE($6,login_id), branch=COALESCE($7,branch), year=COALESCE($8,year), semester=COALESCE($9,semester), batch_no=COALESCE($10,batch_no) WHERE id=$11")
                .bind(full_name).bind(phone).bind(email).bind(exp).bind(dob_str).bind(login_id).bind(branch).bind(year).bind(semester).bind(batch_no).bind(user_uuid).execute(&state.pool).await.ok();
             sqlx::query("UPDATE profile_update_requests SET status='APPROVED' WHERE id=$1").bind(request_id).execute(&state.pool).await.ok();
             sqlx::query("UPDATE notifications SET status='ACCEPTED' WHERE id=$1").bind(payload.notification_id).execute(&state.pool).await.ok();
        }
    } else {
        sqlx::query("UPDATE profile_update_requests SET status='REJECTED' WHERE user_id=$1 AND status='PENDING'").bind(user_uuid).execute(&state.pool).await.ok();
        sqlx::query("UPDATE notifications SET status='REJECTED' WHERE id=$1").bind(payload.notification_id).execute(&state.pool).await.ok();
    }
    Ok(StatusCode::OK)
}

pub async fn approve_attendance_correction_handler(
    State(state): State<AppState>,
    Json(payload): Json<ApproveAttendanceCorrectionData>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let request_row: Option<(Uuid, serde_json::Value)> = sqlx::query_as("SELECT id, dates FROM attendance_correction_requests WHERE user_id = $1 AND status = 'PENDING' LIMIT 1").bind(payload.sender_id).fetch_optional(&state.pool).await.ok().flatten();
    let (request_id, dates_val) = match request_row {
        Some(r) => r,
        None => return Err((StatusCode::NOT_FOUND, Json(serde_json::json!({"error": "No pending request found"})))),
    };

    #[derive(serde::Deserialize)]
    struct LocalItem { date: String, session: String }
    let items: Vec<LocalItem> = serde_json::from_value(dates_val).unwrap();

    if payload.action == "APPROVE" {
        for item in items {
             let parsed_date = chrono::NaiveDate::parse_from_str(&item.date, "%Y-%m-%d").unwrap_or_default();
             sqlx::query("UPDATE attendance SET status = 'P' WHERE student_uuid = $1 AND date = $2 AND session = $3").bind(payload.sender_id).bind(parsed_date).bind(&item.session).execute(&state.pool).await.ok();
        }
        sqlx::query("UPDATE attendance_correction_requests SET status = 'APPROVED' WHERE id = $1").bind(request_id).execute(&state.pool).await.ok();
        sqlx::query("INSERT INTO notifications (type, message, sender_id, recipient_id, status, created_at) VALUES ($1, $2, $3, $4, 'UNREAD', NOW())").bind("ATTENDANCE_CORRECTION_RESULT").bind("Your attendance correction request has been APPROVED.").bind("SYSTEM").bind(payload.sender_id.to_string()).execute(&state.pool).await.ok();
    } else {
        sqlx::query("UPDATE attendance_correction_requests SET status = 'REJECTED' WHERE id = $1").bind(request_id).execute(&state.pool).await.ok();
        sqlx::query("INSERT INTO notifications (type, message, sender_id, recipient_id, status, created_at) VALUES ($1, $2, $3, $4, 'UNREAD', NOW())").bind("ATTENDANCE_CORRECTION_RESULT").bind("Your attendance correction request has been REJECTED.").bind("SYSTEM").bind(payload.sender_id.to_string()).execute(&state.pool).await.ok();
    }
    
    if let Some(nid) = payload.notification_id {
         sqlx::query("UPDATE notifications SET status = 'ACCEPTED' WHERE id = $1").bind(nid).execute(&state.pool).await.ok();
    }
    Ok(Json(serde_json::json!({"message": "Processed successfully"})))
}

// --- Timetable ---

pub async fn get_timetable_handler(
    State(state): State<AppState>,
    Query(params): Query<GetTimetableQuery>,
) -> Result<Json<Vec<TimetableEntry>>, StatusCode> {
    let section = params.section.unwrap_or_else(|| "A".to_string());
    let entries = sqlx::query_as::<_, TimetableEntry>("SELECT * FROM timetables WHERE branch = $1 AND year = $2 AND section = $3 ORDER BY day, period_number")
    .bind(normalize_branch(&params.branch)).bind(params.year).bind(section).fetch_all(&state.pool).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(Json(entries))
}

pub async fn assign_class_handler(
    State(state): State<AppState>,
    Json(payload): Json<AssignClassRequest>,
) -> Result<Json<TimetableEntry>, StatusCode> {
    let entry_type = payload.entry_type.unwrap_or_else(|| "class".to_string());
    let entry = sqlx::query_as::<_, TimetableEntry>("INSERT INTO timetables (branch, year, section, day, period_number, start_time, end_time, subject_name, type) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) ON CONFLICT (branch, year, section, day, period_number) DO UPDATE SET subject_name = EXCLUDED.subject_name, start_time = EXCLUDED.start_time, end_time = EXCLUDED.end_time, type = EXCLUDED.type RETURNING *")
    .bind(normalize_branch(&payload.branch)).bind(payload.year).bind(payload.section).bind(payload.day).bind(payload.period_number).bind(payload.start_time).bind(payload.end_time).bind(payload.subject_name).bind(entry_type).fetch_one(&state.pool).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(Json(entry))
}

pub async fn clear_class_handler(
    State(state): State<AppState>,
    Json(payload): Json<ClearClassRequest>,
) -> Result<StatusCode, StatusCode> {
    sqlx::query("DELETE FROM timetables WHERE id = $1").bind(payload.id).execute(&state.pool).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::OK)
}

// --- Helpers ---

async fn resolve_user_id(id_str: &str, role_hint: &str, pool: &sqlx::PgPool) -> Result<Uuid, (StatusCode, Json<serde_json::Value>)> {
    if let Ok(uuid) = Uuid::parse_str(id_str) { return Ok(uuid); }
    let row = sqlx::query("SELECT id FROM users WHERE login_id = $1").bind(id_str).fetch_optional(pool).await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": format!("DB error resolving {}", role_hint)}))))?;
    match row {
        Some(r) => Ok(r.get("id")),
        None => Err((StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": format!("Invalid {} ID: {}", role_hint, id_str)}))))
    }
}

// --- Create Student (HOD) ---
pub async fn create_student_handler(
    State(state): State<AppState>,
    Json(payload): Json<CreateStudentRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let section = payload.section.unwrap_or_else(|| "Section A".to_string());
    
    // Check if exists
    let exists = sqlx::query("SELECT 1 FROM users WHERE login_id = $1")
        .bind(&payload.student_id)
        .fetch_optional(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?;

    if exists.is_some() {
        return Err((StatusCode::CONFLICT, Json(serde_json::json!({"error": "Student ID already exists"}))));
    }

    // Insert
    let branch_norm = normalize_branch(&payload.branch);
    sqlx::query("INSERT INTO users (id, full_name, role, login_id, password_hash, branch, year, section, is_approved, created_at, batch_no, semester) VALUES ($1, $2, 'Student', $3, $4, $5, $6, $7, true, NOW(), $8, $9)")
        .bind(Uuid::new_v4())
        .bind(payload.full_name)
        .bind(payload.student_id.clone())
        .bind(payload.student_id) // Default password
        .bind(branch_norm)
        .bind(payload.year)
        .bind(section)
        .bind(payload.batch)
        .bind(payload.semester)
        .execute(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?;

    Ok(StatusCode::CREATED)
}

pub async fn bulk_create_students_handler(
    State(state): State<AppState>,
    Json(payloads): Json<Vec<CreateStudentRequest>>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let mut tx = state.pool.begin().await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?;

    for payload in payloads {
        let section = payload.section.unwrap_or_else(|| "Section A".to_string());
        let branch_norm = normalize_branch(&payload.branch);

        // Subquery approach to avoid multiple roundtrips for existence if possible, 
        // but simpler for now is just to use a single insert with a WHERE NOT EXISTS
        // Or just let it fail/ignore if login_id exists.
        
        let _ = sqlx::query(
            "INSERT INTO users (id, full_name, role, login_id, password_hash, branch, year, section, is_approved, created_at, batch_no, semester)
             SELECT $1, $2, 'Student', $3, $4, $5, $6, $7, true, NOW(), $8, $9
             WHERE NOT EXISTS (SELECT 1 FROM users WHERE login_id = $10)"
        )
        .bind(Uuid::new_v4())
        .bind(payload.full_name)
        .bind(&payload.student_id)
        .bind(&payload.student_id) 
        .bind(branch_norm)
        .bind(payload.year)
        .bind(section)
        .bind(payload.batch)
        .bind(payload.semester)
        .bind(&payload.student_id) // For NOT EXISTS check
        .execute(&mut *tx)
        .await; 
        // We ignore individual errors in bulk sync to keep moving
    }

    tx.commit().await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?;

    Ok(StatusCode::OK)
}

#[derive(serde::Deserialize)]
pub struct SectionsQuery {
    pub branch: String,
    pub year: String,
}

pub async fn get_sections_handler(
    State(state): State<AppState>,
    Query(params): Query<SectionsQuery>,
) -> Result<Json<Vec<String>>, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);

    // 1. Try fetching from explicit 'sections' table
    let config_sections: Vec<String> = sqlx::query_scalar(
        "SELECT section_name FROM sections WHERE branch = $1 AND year = $2 ORDER BY section_name ASC"
    )
    .bind(&branch_norm)
    .bind(&params.year)
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    if !config_sections.is_empty() {
        return Ok(Json(config_sections));
    }

    // 2. Fallback: Query distinct sections from users table where students exist
    let branch_variations = get_branch_variations(&params.branch);
    let year_pattern = format!("{}%", params.year.trim());
    
    let sections: Vec<String> = sqlx::query_scalar(
        "SELECT DISTINCT section FROM users WHERE role = 'Student' AND branch = ANY($1::text[]) AND year LIKE $2 AND section IS NOT NULL ORDER BY section ASC"
    )
    .bind(&branch_variations)
    .bind(year_pattern)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        eprintln!("Fetch Sections Error: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    if sections.is_empty() {
        // Absolute fallback
        Ok(Json(vec!["Section A".to_string()]))
    } else {
        Ok(Json(sections))
    }
}

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateSectionsRequest {
    pub branch: String,
    pub year: String,
    pub sections: Vec<String>,
}

pub async fn update_sections_handler(
    State(state): State<AppState>,
    Json(payload): Json<UpdateSectionsRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let branch_norm = normalize_branch(&payload.branch);
    
    let mut tx = state.pool.begin().await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?;

    // Clear existing for this branch/year
    sqlx::query("DELETE FROM sections WHERE branch = $1 AND year = $2")
        .bind(&branch_norm)
        .bind(&payload.year)
        .execute(&mut *tx)
        .await
        .ok();

    // Insert new
    for section in payload.sections {
        sqlx::query("INSERT INTO sections (branch, year, section_name) VALUES ($1, $2, $3)")
            .bind(&branch_norm)
            .bind(&payload.year)
            .bind(section)
            .execute(&mut *tx)
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?;
    }

    tx.commit().await
        .map_err(|_e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Commit Failed"}))))?;

    Ok(StatusCode::OK)
}

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DeleteStudentRequest {
    pub student_id: String,
}

pub async fn delete_student_handler(
    State(state): State<AppState>,
    Json(payload): Json<DeleteStudentRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let result = sqlx::query("DELETE FROM users WHERE login_id = $1 AND role = 'Student'")
        .bind(&payload.student_id)
        .execute(&state.pool)
        .await
        .map_err(|e| {
             eprintln!("Delete Student Error: {:?}", e);
             (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to delete student"})))
        })?;

    if result.rows_affected() == 0 {
        return Err((StatusCode::NOT_FOUND, Json(serde_json::json!({"error": "Student not found"}))));
    }

    Ok(StatusCode::OK)
}

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RenameSectionRequest {
    pub branch: String,
    pub year: String,
    pub old_name: String,
    pub new_name: String,
}

pub async fn rename_section_handler(
    State(state): State<AppState>,
    Json(payload): Json<RenameSectionRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let branch_norm = normalize_branch(&payload.branch);
    let year_pattern = format!("{}%", payload.year.trim());
    let branch_variations = get_branch_variations(&payload.branch);

    let mut tx = state.pool.begin().await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?;

    // 1. Update Students (users table)
    let users_res = sqlx::query("UPDATE users SET section = $1 WHERE section = $2 AND branch = ANY($3::text[]) AND year LIKE $4 AND role = 'Student'")
        .bind(&payload.new_name)
        .bind(&payload.old_name)
        .bind(&branch_variations)
        .bind(&year_pattern)
        .execute(&mut *tx)
        .await;

    if let Err(e) = users_res {
         eprintln!("Rename Users Failed: {:?}", e);
         return Err((StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to update students"}))));
    }

    // 2. Update 'sections' table (if it exists)
    // First, check if old exists, update it. If not, insert new.
    let _ = sqlx::query("UPDATE sections SET section_name = $1 WHERE branch = $2 AND year = $3 AND section_name = $4")
        .bind(&payload.new_name)
        .bind(&branch_norm)
        .bind(&payload.year)
        .bind(&payload.old_name)
        .execute(&mut *tx)
        .await;
    
    // 3. Update related tables (attendance, etc.) - Optional but recommended for consistency
    // Attendance
    // Note: Attendance table stores branch/year/section. Ideally we update history too.
    let _ = sqlx::query("UPDATE attendance SET section = $1 WHERE section = $2 AND branch = ANY($3::text[]) AND year LIKE $4")
        .bind(&payload.new_name)
        .bind(&payload.old_name)
        .bind(&branch_variations)
        .bind(&year_pattern)
        .execute(&mut *tx)
        .await;

    // Faculty Subjects? Often section is part of primary key, update might be tricky or cascade.
    // For now, focus on students. Faculty assignment might need manual re-assign or complex update.
    // Let's at least try updating faculty_subjects if feasible, but user asked for 'student table'.
    
    tx.commit().await
        .map_err(|_e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Commit Failed"}))))?;

    Ok(StatusCode::OK)
}

// --- Department Timings ---

#[derive(serde::Deserialize)]
pub struct DepartmentTimingsQuery {
    pub branch: String,
}

pub async fn get_department_timings(
    State(state): State<AppState>,
    Query(params): Query<DepartmentTimingsQuery>,
) -> Result<Json<DepartmentTiming>, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    
    let timing = sqlx::query_as::<Postgres, DepartmentTiming>(
        "SELECT * FROM department_timings WHERE branch = $1"
    )
    .bind(&branch_norm)
    .fetch_optional(&state.pool)
    .await;

    match timing {
        Ok(Some(t)) => Ok(Json(t)),
        Ok(None) => {
            // Return default
            Ok(Json(DepartmentTiming {
                branch: branch_norm,
                start_hour: 9,
                start_minute: 0,
                class_duration: 50,
                short_break_duration: 10,
                lunch_duration: 50
            }))
        }
        Err(e) => {
            eprintln!("Get Timings Error: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

pub async fn update_department_timings(
    State(state): State<AppState>,
    Json(payload): Json<DepartmentTiming>,
) -> StatusCode {
    let branch_norm = normalize_branch(&payload.branch);

    let res = sqlx::query(
        "INSERT INTO department_timings (branch, start_hour, start_minute, class_duration, short_break_duration, lunch_duration, slot_config)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (branch) DO UPDATE SET
            start_hour = EXCLUDED.start_hour,
            start_minute = EXCLUDED.start_minute,
            class_duration = EXCLUDED.class_duration,
            short_break_duration = EXCLUDED.short_break_duration,
            lunch_duration = EXCLUDED.lunch_duration,
            slot_config = EXCLUDED.slot_config"
    )
    .bind(branch_norm)
    .bind(payload.start_hour)
    .bind(payload.start_minute)
    .bind(payload.class_duration)
    .bind(payload.short_break_duration)
    .bind(payload.lunch_duration)
    .bind(payload.slot_config)
    .execute(&state.pool)
    .await;

    match res {
        Ok(_) => StatusCode::OK,
        Err(e) => {
            eprintln!("Update Timings Error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        }
    }
}
