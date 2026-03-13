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
