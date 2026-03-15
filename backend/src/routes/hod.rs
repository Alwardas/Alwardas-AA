use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
use serde::{Deserialize, Serialize};
use crate::models::AppState;
use uuid::Uuid;
use serde_json::json;
use sqlx::Row;
use crate::models::{MasterTimetableQuery, MasterTimetableResponse, MasterTimetableRow, FacultyClash, TimetableEntry, normalize_branch};
use std::collections::HashMap;

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
    let mut class_combos: Vec<(String, String)> = sqlx::query_as::<(String, String)>(
        "SELECT year, section_name FROM sections WHERE branch = $1 ORDER BY year ASC, section_name ASC"
    )
    .bind(&branch_norm)
    .fetch_all(&data.pool)
    .await
    .unwrap_or_default();

    if class_combos.is_empty() {
        // Fallback to distinct year/section from users table
        class_combos = sqlx::query_as::<(String, String)>(
            "SELECT DISTINCT year, section FROM users WHERE role = 'Student' AND branch = $1 AND year IS NOT NULL AND section IS NOT NULL ORDER BY year ASC, section ASC"
        )
        .bind(&branch_norm)
        .fetch_all(&data.pool)
        .await
        .unwrap_or_default();
    }

    if class_combos.is_empty() {
        // Final fallback if no students/sections exist
        return Ok(Json(MasterTimetableResponse { rows: vec![], faculty_clashes: vec![] }));
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
        // Assuming 8 periods as per requirement
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

    // 5. Detect Faculty Clashes
    // Clashes happen if same faculty is assigned to multiple classes in the same period
    // Map: (PeriodIndex, FacultyID) -> Vec<ClassName>
    let mut faculty_occupancy: HashMap<(i32, String), Vec<String>> = HashMap::new();
    let mut faculty_names: HashMap<String, String> = HashMap::new();

    for row in &rows {
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
        faculty_clashes,
    }))
}
