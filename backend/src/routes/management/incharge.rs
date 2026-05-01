use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
use crate::models::{
    AppState, InchargeTimetableLookupQuery, UpdateClassStatusRequest, ClassPeriodStatus, DailyReportQuery, DailyClassActivityReport
};
use serde_json::json;

pub async fn incharge_timetable_lookup_handler(
    State(state): State<AppState>,
    Query(params): Query<InchargeTimetableLookupQuery>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    match crate::services::management::incharge_service::incharge_timetable_lookup(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn update_class_status_handler(
    State(state): State<AppState>,
    Json(payload): Json<UpdateClassStatusRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::management::incharge_service::update_class_status(&state.pool, payload).await {
        Ok(_) => Ok(StatusCode::OK),
        Err((c, msg)) => Err((c, Json(json!({"message": msg})))),
    }
}

#[derive(serde::Deserialize)]
pub struct SectionStatusQuery {
    pub branch: String,
    pub year: String,
    pub section: String,
    pub date: String,
}

pub async fn get_section_class_status_handler(
    State(state): State<AppState>,
    Query(params): Query<SectionStatusQuery>,
) -> Result<Json<Vec<ClassPeriodStatus>>, StatusCode> {
    match crate::services::management::incharge_service::get_section_class_status(&state.pool, params.branch, params.year, params.section, params.date).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_daily_activity_report_handler(
    State(state): State<AppState>,
    Query(params): Query<DailyReportQuery>,
) -> Result<Json<DailyClassActivityReport>, StatusCode> {
    match crate::services::management::incharge_service::get_daily_activity_report(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}

pub async fn get_branch_daily_detail_report_handler(
    State(state): State<AppState>,
    Query(params): Query<DailyReportQuery>,
) -> Result<Json<Vec<serde_json::Value>>, StatusCode> {
    match crate::services::management::incharge_service::get_branch_daily_detail_report(&state.pool, params).await {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err(e),
    }
}
