use axum::{
    extract::{State, Query, Path},
    Json, http::StatusCode,
};
use serde_json::json;
use uuid::Uuid;

use crate::models::AppState;
use crate::models::finance::*;
use crate::services::finance_service;

pub async fn get_dashboard_stats_handler(
    State(state): State<AppState>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match finance_service::get_dashboard_stats(&state.pool).await {
        Ok(stats) => Ok(Json(json!({
            "success": true,
            "message": "Dashboard stats fetched successfully",
            "data": stats
        }))),
        Err(code) => Err((code, Json(json!({
            "success": false,
            "message": "Failed to fetch dashboard stats",
            "data": null
        })))),
    }
}

pub async fn get_student_fees_handler(
    State(state): State<AppState>,
    Query(params): Query<StudentFeeQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match finance_service::get_student_fees(&state.pool, params).await {
        Ok(res) => Ok(Json(json!({
            "success": true,
            "message": "Student fees list fetched successfully",
            "data": res
        }))),
        Err(code) => Err((code, Json(json!({
            "success": false,
            "message": "Failed to fetch student fees",
            "data": null
        })))),
    }
}

pub async fn get_student_ledger_handler(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match finance_service::get_student_ledger(&state.pool, &id).await {
        Ok(ledger) => Ok(Json(json!({
            "success": true,
            "message": "Student ledger fetched successfully",
            "data": ledger
        }))),
        Err(code) => Err((code, Json(json!({
            "success": false,
            "message": "Failed to fetch student ledger",
            "data": null
        })))),
    }
}

pub async fn update_student_fee_handler(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(payload): Json<UpdateFeeRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match finance_service::update_student_fee(&state.pool, &id, payload).await {
        Ok(_) => Ok(Json(json!({
            "success": true,
            "message": "Student fee updated successfully",
            "data": null
        }))),
        Err(code) => Err((code, Json(json!({
            "success": false,
            "message": "Failed to update student fee",
            "data": null
        })))),
    }
}

pub async fn preview_bulk_adjust_handler(
    State(state): State<AppState>,
    Json(payload): Json<BulkAdjustRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match finance_service::preview_bulk_adjust(&state.pool, payload).await {
        Ok(preview) => Ok(Json(json!({
            "success": true,
            "message": "Bulk adjustment preview generated",
            "data": preview
        }))),
        Err(code) => Err((code, Json(json!({
            "success": false,
            "message": "Failed to generate bulk preview",
            "data": null
        })))),
    }
}

pub async fn submit_bulk_workflow_handler(
    State(state): State<AppState>,
    Json(payload): Json<BulkAdjustRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match finance_service::submit_bulk_workflow(&state.pool, payload).await {
        Ok(workflow_id) => Ok(Json(json!({
            "success": true,
            "message": "Bulk fee operation submitted for approval",
            "data": { "workflowId": workflow_id }
        }))),
        Err(code) => Err((code, Json(json!({
            "success": false,
            "message": "Failed to submit bulk workflow",
            "data": null
        })))),
    }
}

pub async fn preview_excel_upload_handler(
    State(state): State<AppState>,
    Json(payload): Json<ExcelUploadRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match finance_service::preview_excel_upload(&state.pool, payload).await {
        Ok(res) => Ok(Json(json!({
            "success": true,
            "message": "Excel data validation preview",
            "data": res
        }))),
        Err(code) => Err((code, Json(json!({
            "success": false,
            "message": "Failed to validate Excel data",
            "data": null
        })))),
    }
}

pub async fn submit_excel_workflow_handler(
    State(state): State<AppState>,
    Json(payload): Json<ExcelUploadRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match finance_service::submit_excel_workflow(&state.pool, payload).await {
        Ok(workflow_id) => Ok(Json(json!({
            "success": true,
            "message": "Excel import submitted for approval",
            "data": { "workflowId": workflow_id }
        }))),
        Err(code) => Err((code, Json(json!({
            "success": false,
            "message": "Failed to submit Excel workflow",
            "data": null
        })))),
    }
}

pub async fn get_pending_workflows_handler(
    State(state): State<AppState>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match finance_service::get_pending_workflows(&state.pool).await {
        Ok(workflows) => Ok(Json(json!({
            "success": true,
            "message": "Pending approval workflows fetched",
            "data": workflows
        }))),
        Err(code) => Err((code, Json(json!({
            "success": false,
            "message": "Failed to fetch workflows",
            "data": null
        })))),
    }
}

pub async fn handle_approval_action_handler(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Json(payload): Json<ApprovalActionRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match finance_service::handle_approval_action(&state.pool, id, payload).await {
        Ok(_) => Ok(Json(json!({
            "success": true,
            "message": "Workflow action completed successfully",
            "data": null
        }))),
        Err(code) => Err((code, Json(json!({
            "success": false,
            "message": "Failed to process workflow approval",
            "data": null
        })))),
    }
}

pub async fn get_audit_trails_handler(
    State(state): State<AppState>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match finance_service::get_audit_trails(&state.pool).await {
        Ok(audits) => Ok(Json(json!({
            "success": true,
            "message": "Audit logs fetched successfully",
            "data": audits
        }))),
        Err(code) => Err((code, Json(json!({
            "success": false,
            "message": "Failed to fetch audit trails",
            "data": null
        })))),
    }
}

// Student mobile endpoint
pub async fn get_student_mobile_summary_handler(
    State(state): State<AppState>,
    Query(params): Query<crate::models::ProfileQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match finance_service::get_student_mobile_summary(&state.pool, &params.user_id).await {
        Ok(ledger) => Ok(Json(json!({
            "success": true,
            "message": "Student summary fetched",
            "data": ledger
        }))),
        Err(code) => Err((code, Json(json!({
            "success": false,
            "message": "Failed to fetch student mobile summary",
            "data": null
        })))),
    }
}

// Parent mobile endpoint
pub async fn get_parent_mobile_summary_handler(
    State(state): State<AppState>,
    Query(params): Query<crate::models::ProfileQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match finance_service::get_parent_mobile_summary(&state.pool, &params.user_id).await {
        Ok(ledger) => Ok(Json(json!({
            "success": true,
            "message": "Parent ward summary fetched",
            "data": ledger
        }))),
        Err(code) => Err((code, Json(json!({
            "success": false,
            "message": "Failed to fetch parent mobile summary",
            "data": null
        })))),
    }
}

pub async fn pay_simulated_fee_handler(
    State(state): State<AppState>,
    Json(payload): Json<PaySimulatedRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match finance_service::pay_simulated_fee(&state.pool, payload).await {
        Ok(receipt) => Ok(Json(json!({
            "success": true,
            "message": "Simulated payment successful",
            "data": receipt
        }))),
        Err(code) => Err((code, Json(json!({
            "success": false,
            "message": "Simulated payment failed",
            "data": null
        })))),
    }
}
