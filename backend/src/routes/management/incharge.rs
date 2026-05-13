use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
use crate::models::{
    AppState, InchargeTimetableLookupQuery, UpdateClassStatusRequest, DailyReportQuery
};
use serde_json::json;

pub async fn incharge_timetable_lookup_handler(
    State(state): State<AppState>,
    Query(params): Query<InchargeTimetableLookupQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::management::incharge_service::incharge_timetable_lookup(&state.pool, params).await {
        Ok(res) => {
            println!("GET Incharge Timetable Result: Success");
            Ok(Json(json!({
                "success": true,
                "message": "Timetable fetched successfully",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Incharge Timetable Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch timetable",
                "data": null
            }))))
        },
    }
}

pub async fn update_class_status_handler(
    State(state): State<AppState>,
    Json(payload): Json<UpdateClassStatusRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::management::incharge_service::update_class_status(&state.pool, payload).await {
        Ok(res) => {
            println!("UPDATE Class Status Result: {:?}", res);
            Ok(Json(json!({
                "success": true,
                "message": "Class status updated successfully",
                "data": res
            })))
        },
        Err((c, msg)) => {
            println!("UPDATE Class Status Error: {:?}", msg);
            Err((c, Json(json!({
                "success": false,
                "message": msg,
                "data": null
            }))))
        },
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
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::management::incharge_service::get_section_class_status(&state.pool, params.branch, params.year, params.section, params.date).await {
        Ok(res) => {
            println!("GET Section Status Result: {:?}", res.len());
            Ok(Json(json!({
                "success": true,
                "message": "Section status fetched",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Section Status Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch section status",
                "data": null
            }))))
        },
    }
}

pub async fn get_daily_activity_report_handler(
    State(state): State<AppState>,
    Query(params): Query<DailyReportQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::management::incharge_service::get_daily_activity_report(&state.pool, params).await {
        Ok(res) => {
            println!("GET Daily Report Result: Success");
            Ok(Json(json!({
                "success": true,
                "message": "Daily report fetched",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Daily Report Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch daily report",
                "data": null
            }))))
        },
    }
}

pub async fn get_branch_daily_detail_report_handler(
    State(state): State<AppState>,
    Query(params): Query<DailyReportQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::management::incharge_service::get_branch_daily_detail_report(&state.pool, params).await {
        Ok(res) => {
            println!("GET Detail Report Result: {:?}", res.len());
            Ok(Json(json!({
                "success": true,
                "message": "Detail report fetched",
                "data": res
            })))
        },
        Err(e) => {
            println!("GET Detail Report Error: {:?}", e);
            Err((e, Json(json!({
                "success": false,
                "message": "Failed to fetch detail report",
                "data": null
            }))))
        },
    }
}
