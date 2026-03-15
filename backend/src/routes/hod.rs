use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
use serde::{Deserialize, Serialize};
use crate::models::AppState;
use uuid::Uuid;
use serde_json::json;
use sqlx::{Row, Postgres};
use crate::models::{
    MasterTimetableQuery, MasterTimetableResponse, MasterTimetableRow, FacultyClash, 
    TimetableEntry, normalize_branch, BranchProgressResponse, YearProgressResponse,
    SectionProgressResponse, SubjectProgressResponse
};
use std::collections::HashMap;
// use chrono::Utc;

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AddCourseSubjectRequest {
    pub branch: String,
    pub year: String,
    pub section: String,
    pub subject_name: String,
    pub subject_code: String,
    pub created_by: String, // hod_id
    pub course_id: Option<String>,
}

#[derive(Deserialize)]
pub struct SectionQuery {
    pub branch: String,
    pub year: String,
}

#[derive(Deserialize)]
pub struct SubjectQuery {
    pub branch: String,
    pub year: String,
}

pub async fn get_hod_departments_handler(
    State(data): State<AppState>,
) -> Result<Json<Vec<String>>, StatusCode> {
    let result = sqlx::query_scalar("SELECT branch FROM department_timings")
        .fetch_all(&data.pool)
        .await
        .map_err(|e| {
            eprintln!("Failed to fetch department branches: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    Ok(Json(result))
}

pub async fn get_hod_sections_handler(
    State(data): State<AppState>,
    Query(params): Query<SectionQuery>,
) -> Result<Json<Vec<String>>, StatusCode> {
    let result = sqlx::query_scalar("SELECT section_name FROM sections WHERE branch = $1 AND year = $2")
        .bind(&params.branch)
        .bind(&params.year)
        .fetch_all(&data.pool)
        .await
        .map_err(|e| {
            eprintln!("Failed to fetch sections: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    Ok(Json(result))
}

pub async fn get_hod_subjects_handler(
    State(data): State<AppState>,
    Query(params): Query<SubjectQuery>,
) -> Result<Json<Vec<String>>, StatusCode> {
    let result = sqlx::query_scalar("SELECT name FROM subjects WHERE branch = $1 AND year = $2")
        .bind(&params.branch)
        .bind(&params.year)
        .fetch_all(&data.pool)
        .await
        .map_err(|e| {
            eprintln!("Failed to fetch subjects: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    Ok(Json(result))
}

pub async fn add_course_subject_handler(
    State(data): State<AppState>,
    Json(payload): Json<AddCourseSubjectRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    // 1. Check if subject already exists for the selected Branch + Year + Section
    let existing: Option<Uuid> = sqlx::query_scalar(
        "SELECT id FROM course_subjects WHERE branch = $1 AND year = $2 AND section = $3 AND subject_name = $4"
    )
    .bind(&payload.branch)
    .bind(&payload.year)
    .bind(&payload.section)
    .bind(&payload.subject_name)
    .fetch_optional(&data.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": e.to_string()}))))?;

    if existing.is_some() {
        return Err((StatusCode::CONFLICT, Json(json!({"message": "Subject already assigned."}))));
    }

    // 2. Insert new record
    sqlx::query(
        "INSERT INTO course_subjects (branch, year, section, subject_name, subject_code, created_by, course_id) VALUES ($1, $2, $3, $4, $5, $6, $7)"
    )
    .bind(&payload.branch)
    .bind(&payload.year)
    .bind(&payload.section)
    .bind(&payload.subject_name)
    .bind(&payload.subject_code)
    .bind(&payload.created_by)
    .bind(payload.course_id.unwrap_or_else(|| "C-23".to_string()))
    .execute(&data.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": e.to_string()}))))?;

    Ok(StatusCode::OK)
}

pub async fn get_added_course_subjects_handler(
    State(data): State<AppState>,
    Query(params): Query<crate::models::ProfileQuery>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let result = sqlx::query(
        "SELECT id, branch, year, section, subject_name, subject_code FROM course_subjects WHERE created_by = $1 ORDER BY subject_code ASC, subject_name ASC"
    )
    .bind(&params.user_id)
    .fetch_all(&data.pool)
    .await
    .map_err(|e| {
        eprintln!("Failed to fetch added course subjects: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    let subjects: Vec<serde_json::Value> = result.into_iter().map(|row| {
        json!({
            "id": row.get::<Uuid, _>("id"),
            "branch": row.get::<String, _>("branch"),
            "year": row.get::<String, _>("year"),
            "section": row.get::<String, _>("section"),
            "subjectName": row.get::<String, _>("subject_name"),
            "subject_id": row.get::<Option<String>, _>("subject_code").unwrap_or_default(),
        })
    }).collect();

    Ok(Json(json!(subjects)))
}

pub async fn get_master_timetable_handler(
    State(data): State<AppState>,
    Query(params): Query<MasterTimetableQuery>,
) -> Result<Json<MasterTimetableResponse>, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    let day = &params.day;

    // 1. Get all year + section combinations for this branch
    // Check 'sections' table first, fallback to users if needed
    let mut class_combos: Vec<(String, String)> = sqlx::query_as::<Postgres, (String, String)>(
        "SELECT year, section_name FROM sections WHERE branch = $1 ORDER BY year ASC, section_name ASC"
    )
    .bind(&branch_norm)
    .fetch_all(&data.pool)
    .await
    .unwrap_or_default();

    if class_combos.is_empty() {
        // Fallback to distinct year/section from users table
        class_combos = sqlx::query_as::<Postgres, (String, String)>(
            "SELECT DISTINCT year, section FROM users WHERE role = 'Student' AND branch = $1 AND year IS NOT NULL AND section IS NOT NULL ORDER BY year ASC, section ASC"
        )
        .bind(&branch_norm)
        .fetch_all(&data.pool)
        .await
        .unwrap_or_default();
    }

    if class_combos.is_empty() {
        // Final fallback if no students/sections exist
        return Ok(Json(MasterTimetableResponse { rows: vec![], lab_rows: vec![], faculty_clashes: vec![] }));
    }

    // 2. Fetch all timetable entries for this branch and day
    let entries = sqlx::query_as::<Postgres, TimetableEntry>(
        r#"
        SELECT 
            t.id, t.faculty_id, t.branch, t.year, t.section, t.day, t.period_index, t.subject, t.subject_code,
            u.full_name as faculty_name, u.email as faculty_email, u.phone_number as faculty_phone, u.branch as faculty_department
        FROM timetable_entries t
        LEFT JOIN users u ON t.faculty_id = u.login_id
        WHERE t.branch = $1 AND t.day = $2
        "#
    )
    .bind(&branch_norm)
    .bind(day)
    .fetch_all(&data.pool)
    .await
    .map_err(|e| {
        eprintln!("Master Timetable Fetch Error: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    // 3. Build group map for fast lookup
    // Map: (Year, Section) -> Map: PeriodIndex -> Entry
    let mut entries_map: HashMap<(String, String), HashMap<i32, TimetableEntry>> = HashMap::new();
    for entry in entries {
        entries_map
            .entry((entry.year.clone(), entry.section.clone()))
            .or_default()
            .insert(entry.period_index, entry);
    }

    // 4. Transform into Rows
    let mut rows = Vec::new();
    for (year, section) in class_combos {
        let mut periods = Vec::new();
        for p in 0..8 {
            let entry = entries_map.get(&(year.clone(), section.clone())).and_then(|m| m.get(&p).cloned());
            periods.push(entry);
        }

        rows.push(MasterTimetableRow {
            class_name: format!("{} - {}", year, section),
            year,
            section,
            periods,
        });
    }

    // 4b. Fetch Labs
    let lab_names: Vec<String> = sqlx::query_scalar::<Postgres, String>(
        "SELECT DISTINCT section FROM timetable_entries WHERE branch = $1 AND year = 'Lab' ORDER BY section ASC"
    )
    .bind(&branch_norm)
    .fetch_all(&data.pool)
    .await
    .unwrap_or_default();

    let mut lab_rows = Vec::new();
    for lab_name in lab_names {
        let mut periods = Vec::new();
        for p in 0..8 {
            let entry = entries_map.get(&("Lab".to_string(), lab_name.clone())).and_then(|m| m.get(&p).cloned());
            periods.push(entry);
        }

        lab_rows.push(MasterTimetableRow {
            class_name: lab_name.clone(),
            year: "Lab".to_string(),
            section: lab_name,
            periods,
        });
    }

    // 5. Detect Faculty Clashes
    // Clashes happen if same faculty is assigned to multiple classes (or labs) in the same period
    let mut faculty_occupancy: HashMap<(i32, String), Vec<String>> = HashMap::new();
    let mut faculty_names: HashMap<String, String> = HashMap::new();

    let all_display_rows = rows.iter().chain(lab_rows.iter());

    for row in all_display_rows {
        for (idx, period) in row.periods.iter().enumerate() {
            if let Some(entry) = period {
                let key = (idx as i32, entry.faculty_id.clone());
                faculty_occupancy.entry(key).or_default().push(row.class_name.clone());
                if let Some(name) = &entry.faculty_name {
                    faculty_names.insert(entry.faculty_id.clone(), name.clone());
                }
            }
        }
    }

    let mut faculty_clashes = Vec::new();
    for ((period_idx, faculty_id), classes) in faculty_occupancy {
        if classes.len() > 1 {
            faculty_clashes.push(FacultyClash {
                faculty_name: faculty_names.get(&faculty_id).cloned().unwrap_or(faculty_id),
                day: day.clone(),
                period_index: period_idx,
                classes,
            });
        }
    }

    Ok(Json(MasterTimetableResponse {
        rows,
        lab_rows,
        faculty_clashes,
    }))
}

// --- Syllabus Progress System ---

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BranchProgressQuery {
    pub branch: String,
    pub course_id: String,
}

pub async fn get_branch_progress_handler(
    State(data): State<AppState>,
    Query(params): Query<BranchProgressQuery>,
) -> Result<Json<BranchProgressResponse>, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    let years = vec!["1st Year", "2nd Year", "3rd Year"];
    let mut year_responses = Vec::new();
    let mut total_avg = 0.0;

    for year in years {
        // Average progress of sections in this year
        let progress = calculate_year_progress(&data.pool, &branch_norm, &params.course_id, year).await.unwrap_or(0);
        year_responses.push(YearProgressResponse {
            year: year.to_string(),
            percentage: progress,
        });
        total_avg += progress as f64;
    }

    let overall = (total_avg / 3.0).round() as i32;

    Ok(Json(BranchProgressResponse {
        branch: branch_norm,
        years: year_responses,
        overall_percentage: overall,
    }))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct YearSectionsProgressQuery {
    pub branch: String,
    pub year: String,
    pub course_id: String,
}

pub async fn get_year_sections_progress_handler(
    State(data): State<AppState>,
    Query(params): Query<YearSectionsProgressQuery>,
) -> Result<Json<Vec<SectionProgressResponse>>, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    
    // Get sections for this branch/year
    let mut sections: Vec<String> = sqlx::query_scalar("SELECT section_name FROM sections WHERE branch = $1 AND year = $2")
        .bind(&branch_norm)
        .bind(&params.year)
        .fetch_all(&data.pool)
        .await
        .unwrap_or_default();

    if sections.is_empty() {
        // Fallback to distinct year/section from users table
        let year_pattern = format!("{}%", params.year.trim());
        sections = sqlx::query_scalar(
            "SELECT DISTINCT section FROM users WHERE role = 'Student' AND branch = $1 AND year LIKE $2 AND section IS NOT NULL ORDER BY section ASC"
        )
        .bind(&branch_norm)
        .bind(year_pattern)
        .fetch_all(&data.pool)
        .await
        .unwrap_or_default();
    }

    let mut responses = Vec::new();
    for section in sections {
        let progress = calculate_section_progress(&data.pool, &branch_norm, &params.course_id, &params.year, &section).await.unwrap_or(0);
        responses.push(SectionProgressResponse {
            section_name: section,
            percentage: progress,
        });
    }

    Ok(Json(responses))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SectionSubjectsProgressQuery {
    pub branch: String,
    pub year: String,
    pub section: String,
    pub course_id: String,
    pub semester: Option<String>,
}

pub async fn get_section_subjects_progress_handler(
    State(data): State<AppState>,
    Query(params): Query<SectionSubjectsProgressQuery>,
) -> Result<Json<Vec<SubjectProgressResponse>>, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    
    #[derive(sqlx::FromRow)]
    struct SubjectInfo { id: String, name: String }

    let semester_pattern = params.semester.as_ref().map(|s| {
        match s.as_str() {
            "Semester 1" => vec!["1st Year".to_string(), "1st Semester".to_string()],
            "Semester 3" => vec!["3rd Semester".to_string(), "3rd".to_string()],
            "Semester 4" => vec!["4th Semester".to_string()],
            "Semester 5" => vec!["5th Semester".to_string()],
            "Semester 6" => vec!["6th Semester".to_string()],
            _ => vec![s.clone()],
        }
    });

    let subjects = if let Some(patterns) = semester_pattern {
        sqlx::query_as::<Postgres, SubjectInfo>(
            "SELECT id, name FROM subjects 
             WHERE branch = $1 AND (course_id = $2 OR course_id IS NULL) 
             AND semester = ANY($3)
             ORDER BY id ASC"
        )
        .bind(branch_norm)
        .bind(params.course_id)
        .bind(&patterns)
        .fetch_all(&data.pool)
        .await
        .unwrap_or_default()
    } else {
        sqlx::query_as::<Postgres, SubjectInfo>(
            "SELECT id, name FROM subjects 
             WHERE branch = $1 AND (course_id = $2 OR course_id IS NULL) 
             AND (semester LIKE $3 OR semester LIKE $4 OR semester LIKE $5)
             ORDER BY id ASC"
        )
        .bind(branch_norm)
        .bind(params.course_id)
        .bind(format!("{}%", params.year))
        .bind(if params.year == "1st Year" { "1st Semester%" } else if params.year == "2nd Year" { "3rd Semester%" } else { "5th Semester%" })
        .bind(if params.year == "1st Year" { "2nd Semester%" } else if params.year == "2nd Year" { "4th Semester%" } else { "6th Semester%" })
        .fetch_all(&data.pool)
        .await
        .unwrap_or_default()
    };

    let mut responses = Vec::new();
    for sub in subjects {
        let (progress, status) = calculate_subject_progress(&data.pool, &sub.id, &params.section).await;
        responses.push(SubjectProgressResponse {
            subject_id: sub.id,
            subject_name: sub.name,
            percentage: progress,
            status,
        });
    }

    Ok(Json(responses))
}

// --- Internal Calculation Helpers ---

async fn calculate_year_progress(pool: &sqlx::PgPool, branch: &str, course_id: &str, year: &str) -> Option<i32> {
    let mut sections: Vec<String> = sqlx::query_scalar("SELECT section_name FROM sections WHERE branch = $1 AND year = $2")
        .bind(branch)
        .bind(year)
        .fetch_all(pool)
        .await
        .unwrap_or_default();

    if sections.is_empty() {
        let year_pattern = format!("{}%", year.trim());
        sections = sqlx::query_scalar("SELECT DISTINCT section FROM users WHERE role = 'Student' AND branch = $1 AND year LIKE $2 AND section IS NOT NULL")
            .bind(branch)
            .bind(year_pattern)
            .fetch_all(pool)
            .await
            .unwrap_or_default();
    }

    if sections.is_empty() { return Some(0); }

    let mut total = 0.0;
    for section in &sections {
        total += calculate_section_progress(pool, branch, course_id, year, section).await.unwrap_or(0) as f64;
    }

    Some((total / sections.len() as f64).round() as i32)
}

async fn calculate_section_progress(pool: &sqlx::PgPool, branch: &str, course_id: &str, year: &str, section: &str) -> Option<i32> {
    #[derive(sqlx::FromRow)]
    struct SubjectIdOnly { id: String }

    let subjects = sqlx::query_as::<Postgres, SubjectIdOnly>(
        "SELECT id FROM subjects WHERE branch = $1 AND (course_id = $2 OR course_id IS NULL) AND (semester LIKE $3 OR semester LIKE $4 OR semester LIKE $5)"
    )
    .bind(branch)
    .bind(course_id)
    .bind(format!("{}%", year))
    .bind(if year == "1st Year" { "1st Semester%" } else if year == "2nd Year" { "3rd Semester%" } else { "5th Semester%" })
    .bind(if year == "1st Year" { "2nd Semester%" } else if year == "2nd Year" { "4th Semester%" } else { "6th Semester%" })
    .fetch_all(pool)
    .await
    .unwrap_or_default();

    if subjects.is_empty() { return Some(0); }

    let mut total = 0.0;
    for sub in &subjects {
        let (progress, _) = calculate_subject_progress(pool, &sub.id, section).await;
        total += progress as f64;
    }

    Some((total / subjects.len() as f64).round() as i32)
}

async fn calculate_subject_progress(pool: &sqlx::PgPool, subject_id: &str, section: &str) -> (i32, String) {
    let stats = sqlx::query(
        r#"
        SELECT 
            COUNT(lpi.id) as total_topics,
            COUNT(CASE WHEN lp.completed = TRUE THEN 1 END) as completed_topics,
            COUNT(CASE WHEN ls.schedule_date <= NOW() THEN 1 END) as scheduled_topics
        FROM lesson_plan_items lpi
        LEFT JOIN lesson_plan_progress lp ON lpi.id = lp.item_id AND lp.section = $2
        LEFT JOIN lesson_schedule ls ON lpi.id = ls.topic_id AND ls.section = $2
        WHERE lpi.subject_id = $1
        "#
    )
    .bind(subject_id)
    .bind(section)
    .fetch_one(pool)
    .await
    .ok();

    if let Some(s) = stats {
        let total: i64 = s.get("total_topics");
        let completed: i64 = s.get("completed_topics");
        let scheduled: i64 = s.get("scheduled_topics");

        let percentage = if total > 0 { (completed as f64 * 100.0 / total as f64).round() as i32 } else { 0 };
        
        let status = if completed < scheduled {
            "Lagging".to_string()
        } else if completed > scheduled {
            "Over Fast".to_string()
        } else {
            "On Track".to_string()
        };

        (percentage, status)
    } else {
        (0, "On Track".to_string())
    }
}
