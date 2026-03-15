use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
use crate::models::{
    AppState, InchargeTimetableLookupQuery, UpdateClassStatusRequest, TimetableEntry,
    normalize_branch, ClassPeriodStatus, DailyReportQuery, DailyClassActivityReport
};
use serde_json::json;
use sqlx::Row;
use chrono::NaiveDate;

pub async fn incharge_timetable_lookup_handler(
    State(data): State<AppState>,
    Query(params): Query<InchargeTimetableLookupQuery>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    
    let entry = sqlx::query_as::<_, TimetableEntry>(
        r#"
        SELECT 
            t.id, t.faculty_id, t.branch, t.year, t.section, t.day, t.period_index, t.subject, t.subject_code,
            u.full_name as faculty_name, u.email as faculty_email, u.phone_number as faculty_phone, u.branch as faculty_department
        FROM timetable_entries t
        LEFT JOIN users u ON t.faculty_id = u.login_id
        WHERE t.branch = $1 AND t.year = $2 AND t.section = $3 AND t.day = $4 AND t.period_index = $5
        "#
    )
    .bind(branch_norm)
    .bind(params.year)
    .bind(params.section)
    .bind(params.day)
    .bind(params.period_index)
    .fetch_optional(&data.pool)
    .await
    .map_err(|e| {
        eprintln!("Timetable Lookup Error: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    match entry {
        Some(e) => Ok(Json(json!({
            "subject": e.subject,
            "faculty": e.faculty_name.unwrap_or_else(|| e.faculty_id)
        }))),
        None => Ok(Json(json!({
            "subject": "No Class",
            "faculty": "---"
        })))
    }
}

pub async fn update_class_status_handler(
    State(data): State<AppState>,
    Json(payload): Json<UpdateClassStatusRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let branch_norm = normalize_branch(&payload.branch);
    let status_date = NaiveDate::parse_from_str(&payload.status_date, "%Y-%m-%d")
        .map_err(|_| (StatusCode::BAD_REQUEST, Json(json!({"message": "Invalid date format"}))))?;

    sqlx::query(
        r#"
        INSERT INTO class_period_status (
            branch, year, section, day, period_index, status_date,
            original_subject, original_faculty, actual_subject, actual_faculty, 
            status, updated_by
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        ON CONFLICT (branch, year, section, day, period_index, status_date) DO UPDATE SET
            actual_subject = EXCLUDED.actual_subject,
            actual_faculty = EXCLUDED.actual_faculty,
            status = EXCLUDED.status,
            updated_by = EXCLUDED.updated_by,
            updated_at = NOW()
        "#
    )
    .bind(branch_norm)
    .bind(payload.year)
    .bind(payload.section)
    .bind(payload.day)
    .bind(payload.period_index)
    .bind(status_date)
    .bind(payload.original_subject)
    .bind(payload.original_faculty)
    .bind(payload.actual_subject)
    .bind(payload.actual_faculty)
    .bind(payload.status)
    .bind(payload.updated_by)
    .execute(&data.pool)
    .await
    .map_err(|e| {
        eprintln!("Update Class Status Error: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": e.to_string()})))
    })?;

    Ok(StatusCode::OK)
}

#[derive(serde::Deserialize)]
pub struct SectionStatusQuery {
    pub branch: String,
    pub year: String,
    pub section: String,
    pub date: String,
}

pub async fn get_section_class_status_handler(
    State(data): State<AppState>,
    Query(params): Query<SectionStatusQuery>,
) -> Result<Json<Vec<ClassPeriodStatus>>, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    let date = NaiveDate::parse_from_str(&params.date, "%Y-%m-%d")
        .map_err(|_| StatusCode::BAD_REQUEST)?;

    let result = sqlx::query_as::<_, ClassPeriodStatus>(
        "SELECT * FROM class_period_status WHERE branch = $1 AND year = $2 AND section = $3 AND status_date = $4"
    )
    .bind(branch_norm)
    .bind(params.year)
    .bind(params.section)
    .bind(date)
    .fetch_all(&data.pool)
    .await
    .map_err(|e| {
        eprintln!("Fetch Section Status Error: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    Ok(Json(result))
}

pub async fn get_daily_activity_report_handler(
    State(data): State<AppState>,
    Query(params): Query<DailyReportQuery>,
) -> Result<Json<DailyClassActivityReport>, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    let date = NaiveDate::parse_from_str(&params.date, "%Y-%m-%d")
        .map_err(|_| StatusCode::BAD_REQUEST)?;
    
    let day = date.format("%A").to_string();

    let stats = sqlx::query(
        r#"
        SELECT 
            COUNT(*) as total,
            COUNT(CASE WHEN status = 'conducted' THEN 1 END) as conducted,
            COUNT(CASE WHEN status = 'substitute' THEN 1 END) as substitute,
            COUNT(CASE WHEN status = 'not_conducted' THEN 1 END) as not_conducted
        FROM class_period_status
        WHERE branch = $1 AND status_date = $2
        "#
    )
    .bind(branch_norm)
    .bind(date)
    .fetch_one(&data.pool)
    .await
    .map_err(|e| {
        eprintln!("Daily Report Error: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    Ok(Json(DailyClassActivityReport {
        day,
        date: params.date,
        total_classes: stats.get("total"),
        conducted: stats.get("conducted"),
        substitute: stats.get("substitute"),
        not_conducted: stats.get("not_conducted"),
    }))
}
