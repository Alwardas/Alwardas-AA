use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;
use chrono::{DateTime, Utc, NaiveDate};

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct DashboardStats {
    pub total_students: i64,
    pub total_fee_demand: f64,
    pub total_fee_collected: f64,
    pub pending_fees: f64,
    pub todays_collection: f64,
    pub scholarship_amount: f64,
    pub fine_amount: f64,
    pub collection_percentage: f64,
    pub monthly_collection: Vec<ChartDataPoint>,
    pub department_collection: Vec<ChartDataPoint>,
    pub course_collection: Vec<ChartDataPoint>,
    pub pending_fee_analysis: Vec<ChartDataPoint>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ChartDataPoint {
    pub label: String,
    pub value: f64,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct StudentFeeQuery {
    pub student_id: Option<String>,
    pub student_name: Option<String>,
    pub department: Option<String>, // maps to branch
    pub course: Option<String>,
    pub year: Option<String>,
    pub section: Option<String>,
    pub fee_status: Option<String>,
    pub scholarship_status: Option<String>, // 'Yes' or 'No'
    pub page: Option<i64>,
    pub limit: Option<i64>,
}

#[derive(Serialize, Debug, Clone, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct StudentFeeRow {
    pub student_uuid: Uuid,
    pub student_id: String, // login_id
    pub student_name: String, // full_name
    pub department: Option<String>, // branch
    pub total_fee: f64,
    pub paid_amount: f64,
    pub pending_amount: f64,
    pub scholarship_amount: f64,
    pub fine_amount: f64,
    pub last_payment_date: Option<DateTime<Utc>>,
    pub status: String,
    pub scholarship_status: String,
}

#[derive(Serialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct StudentFeeListResponse {
    pub students: Vec<StudentFeeRow>,
    pub total_count: i64,
    pub page: i64,
    pub limit: i64,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct FeeBreakdownItem {
    pub category: String,
    pub amount: f64,
    pub scholarship: f64,
    pub fine: f64,
    pub remarks: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct StudentLedger {
    pub student_uuid: Uuid,
    pub student_id: String,
    pub student_name: String,
    pub department: Option<String>,
    pub year: Option<String>,
    pub section: Option<String>,
    pub total_fee: f64,
    pub paid_amount: f64,
    pub pending_amount: f64,
    pub scholarship_amount: f64,
    pub fine_amount: f64,
    pub status: String,
    pub breakdown: Vec<FeeBreakdownItem>,
    pub payment_history: Vec<PaymentReceipt>,
    pub change_history: Vec<FeeChangeLog>,
}

#[derive(Serialize, Deserialize, Debug, Clone, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct PaymentReceipt {
    pub receipt_number: String,
    pub amount: f64,
    pub payment_mode: String,
    pub transaction_date: DateTime<Utc>,
    pub status: String,
    pub reference_number: Option<String>,
    pub remarks: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct FeeChangeLog {
    pub id: Uuid,
    pub category: String,
    pub previous_amount: f64,
    pub new_amount: f64,
    pub reason: String,
    pub updated_by_name: String,
    pub updated_at: DateTime<Utc>,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct UpdateFeeRequest {
    pub category: String,
    pub amount: f64,
    pub scholarship: f64,
    pub fine: f64,
    pub reason: String,
    pub updated_by: String, // uuid or login_id
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct BulkAdjustRequest {
    pub scope: String, // 'College', 'Department', 'Year', 'Course', 'Section', 'Hostel', 'Transport', 'Group'
    pub target_value: Option<String>, // e.g. 'Computer Engineering', '1st Year', etc.
    pub operation_type: String, // 'Add Fee', 'Reduce Fee', 'Apply Scholarship', 'Add Fine', 'Fee Adjustment'
    pub category: String,
    pub amount: f64,
    pub reason: String,
    pub created_by: String,
}

#[derive(Serialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct BulkAdjustPreview {
    pub affected_students: i64,
    pub current_total_amount: f64,
    pub updated_total_amount: f64,
    pub difference: f64,
    pub reason: String,
    pub operation_type: String,
    pub category: String,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ExcelUploadRequest {
    pub file_name: String,
    pub rows: Vec<ExcelRow>,
    pub created_by: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ExcelRow {
    pub student_id: String,
    pub amount: f64,
    pub fee_category: String,
    pub reason: String,
}

#[derive(Serialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ExcelValidationResult {
    pub row_index: usize,
    pub student_id: String,
    pub is_valid: bool,
    pub error_message: Option<String>,
    pub student_name: Option<String>,
    pub current_amount: Option<f64>,
}

#[derive(Serialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ExcelPreviewResponse {
    pub validation_results: Vec<ExcelValidationResult>,
    pub is_valid_overall: bool,
    pub total_students: i64,
    pub total_current_amount: f64,
    pub total_new_amount: f64,
    pub difference: f64,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ApplyBulkChangesRequest {
    pub workflow_id: Option<Uuid>, // if executing pre-saved workflow
    pub operation_type: String, // 'BULK_ADJUST' or 'EXCEL_UPLOAD' or 'SINGLE_UPDATE'
    pub payload: serde_json::Value,
    pub reason: String,
    pub created_by: String,
    pub verified: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct WorkflowItem {
    pub id: Uuid,
    pub operation_type: String,
    pub payload: serde_json::Value,
    pub status: String,
    pub created_by_name: String,
    pub student_count: i32,
    pub total_difference: f64,
    pub reason: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub approved_by_admin_name: Option<String>,
    pub approved_by_principal_name: Option<String>,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ApprovalActionRequest {
    pub action: String, // 'APPROVE' or 'REJECT'
    pub reason: Option<String>, // rejection reason
    pub user_id: String, // actor's user id
}

#[derive(Serialize, Debug, Clone, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct AuditTrailRow {
    pub id: Uuid,
    pub operation_id: Option<Uuid>,
    pub operation_type: String,
    pub student_count: i32,
    pub created_by_name: String,
    pub approved_by_name: Option<String>,
    pub reason: String,
    pub ip_address: Option<String>,
    pub status: String,
    pub timestamp: DateTime<Utc>,
}

#[derive(Serialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct StudentMobileSummary {
    pub student_name: String,
    pub student_id: String,
    pub department: Option<String>,
    pub total_fee: f64,
    pub paid_amount: f64,
    pub pending_amount: f64,
    pub next_due_date: Option<NaiveDate>,
    pub next_due_amount: f64,
}

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct PaySimulatedRequest {
    pub student_id: String,
    pub amount: f64,
    pub payment_mode: String,
    pub remarks: Option<String>,
}
