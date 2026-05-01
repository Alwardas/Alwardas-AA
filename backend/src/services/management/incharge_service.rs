use sqlx::{PgPool};
use axum::http::StatusCode;
use chrono::NaiveDate;
use crate::models::{
    InchargeTimetableLookupQuery, UpdateClassStatusRequest,
    normalize_branch, ClassPeriodStatus, DailyReportQuery, DailyClassActivityReport
};
use crate::repositories::management::incharge_repository;

pub async fn incharge_timetable_lookup(pool: &PgPool, params: InchargeTimetableLookupQuery) -> Result<serde_json::Value, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    
    let entry = incharge_repository::find_timetable_entry(pool, &branch_norm, &params.year, &params.section, &params.day, params.period_index)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    match entry {
        Some(e) => Ok(serde_json::json!({ "subject": e.subject, "faculty": e.faculty_name.unwrap_or_else(|| e.faculty_id) })),
        None => Ok(serde_json::json!({ "subject": "No Class", "faculty": "---" }))
    }
}

pub async fn update_class_status(pool: &PgPool, payload: UpdateClassStatusRequest) -> Result<(), (StatusCode, String)> {
    let branch_norm = normalize_branch(&payload.branch);
    let status_date = NaiveDate::parse_from_str(&payload.status_date, "%Y-%m-%d").map_err(|_| (StatusCode::BAD_REQUEST, "Invalid date format".to_string()))?;

    incharge_repository::upsert_class_status(
        pool, 
        &branch_norm, 
        &payload.year, 
        &payload.section, 
        &payload.day, 
        payload.period_index, 
        status_date, 
        &payload.original_subject, 
        &payload.original_faculty, 
        Some(payload.actual_subject.as_str()), 
        Some(payload.actual_faculty.as_str()), 
        &payload.status, 
        &payload.updated_by.to_string()
    ).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(())
}

pub async fn get_section_class_status(pool: &PgPool, branch: String, year: String, section: String, date_str: String) -> Result<Vec<ClassPeriodStatus>, StatusCode> {
    let branch_norm = normalize_branch(&branch);
    let date = NaiveDate::parse_from_str(&date_str, "%Y-%m-%d").map_err(|_| StatusCode::BAD_REQUEST)?;

    incharge_repository::find_class_statuses(pool, &branch_norm, &year, &section, date)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_daily_activity_report(pool: &PgPool, params: DailyReportQuery) -> Result<DailyClassActivityReport, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    let date = NaiveDate::parse_from_str(&params.date, "%Y-%m-%d").map_err(|_| StatusCode::BAD_REQUEST)?;
    let day = date.format("%A").to_string();

    let (total, conducted, substitute, not_conducted) = incharge_repository::get_daily_activity_stats(pool, &branch_norm, date)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(DailyClassActivityReport { day, date: params.date, total_classes: total, conducted, substitute, not_conducted })
}

pub async fn get_branch_daily_detail_report(pool: &PgPool, params: DailyReportQuery) -> Result<Vec<serde_json::Value>, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    let date = NaiveDate::parse_from_str(&params.date, "%Y-%m-%d").map_err(|_| StatusCode::BAD_REQUEST)?;
    let day = date.format("%A").to_string();

    incharge_repository::find_daily_detail_report(pool, &branch_norm, date, &day)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}
