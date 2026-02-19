use serde::{Deserialize, Serialize};
use sqlx::{Pool, Postgres, FromRow};
use uuid::Uuid;
// HashMap removed

use chrono::{DateTime, Utc};

#[derive(Clone)]
pub struct AppState {
    pub pool: Pool<Postgres>,
}

pub fn normalize_branch(input: &str) -> String {
    match input.trim() {
        // Computer
        "CME" | "CM" | "Cme" | "Computer" => "Computer Engineering".to_string(),
        // ECE
        "ECE" | "EC" | "Ece" => "Electronics & Communication Engineering".to_string(),
        // EEE
        "EEE" | "EE" | "Eee" => "Electrical & Electronics Engineering".to_string(),
        // Mechanical
        "ME" | "MEC" | "MECH" | "Mech" | "Mechanical" | "M" => "Mechanical Engineering".to_string(),
        // Civil
        "CE" | "CIV" | "CIVIL" | "Civil" => "Civil Engineering".to_string(),
        // BS & H / General
        "BS & H" | "BS&H" | "BSH" | "General" | "Basic Science" => "General".to_string(),
        // Default
        _ => input.trim().to_string(),
    }
}

pub fn get_branch_variations(input: &str) -> Vec<String> {
    let normalized = normalize_branch(input);
    let mut variations = vec![normalized.clone()];
    
    match normalized.as_str() {
        "Computer Engineering" => variations.extend(vec!["CME".to_string(), "CM".to_string(), "Computer".to_string()]),
        "Electronics & Communication Engineering" => variations.extend(vec!["ECE".to_string(), "EC".to_string()]),
        "Electrical & Electronics Engineering" => variations.extend(vec!["EEE".to_string(), "EE".to_string()]),
        "Mechanical Engineering" => variations.extend(vec!["ME".to_string(), "MEC".to_string(), "MECH".to_string(), "Mechanical".to_string()]),
        "Civil Engineering" => variations.extend(vec!["CE".to_string(), "CIV".to_string(), "CIVIL".to_string(), "Civil".to_string()]),
        "General" => variations.extend(vec!["BS & H".to_string(), "BS&H".to_string(), "BSH".to_string(), "Basic Science".to_string()]),
        _ => {}
    }
    
    // Also include the original input just in case
    variations.push(input.trim().to_string());
    variations.sort();
    variations.dedup();
    variations
}

#[derive(Serialize, Deserialize, Debug)]
pub struct SignupRequest {
    pub full_name: String,
    pub role: String,
    pub login_id: String,       // Maps to studentId, facultyId, etc. from frontend
    pub password: String,
    pub branch: Option<String>,
    pub year: Option<String>,
    pub section: Option<String>,
    pub phone_number: Option<String>,
    pub dob: Option<String>, // "YYYY-MM-DD"
    pub experience: Option<String>,
    pub email: Option<String>,
    pub semester: Option<String>,
    pub batch_no: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct LoginRequest {
    pub login_id: String,
    pub password: String,
}

#[derive(Serialize, Debug)]
pub struct AuthResponse {
    pub id: Option<String>,
    pub message: String,
    pub role: Option<String>,
    pub full_name: Option<String>,
    pub login_id: Option<String>,
    pub branch: Option<String>,
    pub year: Option<String>,
    pub semester: Option<String>,
    pub batch_no: Option<String>,
    pub section: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, FromRow)]
pub struct Notification {
    pub id: Uuid,
    #[serde(rename = "type")]
    #[sqlx(rename = "type")]
    pub notification_type: String,
    pub message: String,
    #[serde(rename = "senderId")]
    pub sender_id: Option<String>,
    #[serde(rename = "recipientId")]
    pub recipient_id: Option<String>,
    pub branch: Option<String>,
    pub status: String,
    #[serde(rename = "createdAt")]
    pub created_at: DateTime<Utc>,
}

#[derive(Serialize, Deserialize, Debug, FromRow)]
pub struct TimetableEntry {
    pub id: Uuid,
    pub faculty_id: String,
    pub branch: String,
    pub year: String,
    pub section: String,
    pub day: String,
    pub period_index: i32,
    pub subject: String,
    pub subject_code: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct AssignClassRequest {
    #[serde(rename = "facultyId")]
    pub faculty_id: String,
    pub branch: String,
    pub year: String,
    pub section: String,
    pub day: String,
    #[serde(rename = "periodIndex")]
    pub period_index: i32,
    pub subject: String,
    #[serde(rename = "subjectCode")]
    pub subject_code: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, FromRow)]
pub struct DepartmentTiming {
    pub branch: String,
    pub start_hour: i32,
    pub start_minute: i32,
    pub class_duration: i32,
    pub short_break_duration: i32,
    pub lunch_duration: i32,
    pub short_code: Option<String>,
    pub slot_config: Option<serde_json::Value>, 
}

#[derive(Deserialize)]
pub struct NotificationQuery {
    #[serde(rename = "userId")]
    pub user_id: Option<String>,
    pub role: Option<String>,
    pub branch: Option<String>,
}

#[derive(Deserialize)]
pub struct DeleteNotificationsRequest {
    pub ids: Vec<Uuid>,
}

#[derive(Deserialize)]
pub struct ApprovalRequest {
    #[serde(rename = "requestId")]
    pub request_id: Uuid,
    #[serde(rename = "senderId")]
    pub sender_id: String,
    pub action: String, // "APPROVE" or "REJECT"
}

#[derive(Serialize, Deserialize, Debug, FromRow)]
pub struct Issue {
    pub id: Uuid,
    #[serde(rename = "userId")]
    #[sqlx(rename = "user_id")]
    pub user_id: Uuid,
    pub subject: String,
    pub description: String,
    pub status: String,
    pub response: Option<String>,
    #[serde(rename = "respondedBy")]
    #[sqlx(rename = "responded_by")]
    pub responded_by: Option<Uuid>,
    #[serde(rename = "createdAt")]
    #[sqlx(rename = "created_at")]
    pub created_at: DateTime<Utc>,
    #[serde(rename = "reactedAt")]
    #[sqlx(rename = "reacted_at")]
    pub reacted_at: Option<DateTime<Utc>>,
    #[serde(rename = "responderName")] 
    #[sqlx(default)] 
    pub responder_name: Option<String>,
}

#[derive(Deserialize)]
pub struct SubmitIssueRequest {
    #[serde(rename = "userId")]
    pub user_id: String,
    pub subject: String,
    pub description: String,
}

#[derive(Deserialize)]
pub struct GetIssuesQuery {
    #[serde(rename = "userId")]
    pub user_id: String,
}

#[derive(Deserialize)]
pub struct UpdateUserRequest {
    #[serde(rename = "userId")]
    pub user_id: String,
    #[serde(rename = "fullName")]
    pub full_name: Option<String>,
    #[serde(rename = "phoneNumber")]
    pub phone_number: Option<String>,
    pub email: Option<String>,
    pub experience: Option<String>,
    pub dob: Option<String>, // "YYYY-MM-DD"
    pub branch: Option<String>,
    pub year: Option<String>,
    pub semester: Option<String>,
    #[serde(rename = "batchNo")]
    pub batch_no: Option<String>,
    #[serde(rename = "loginId")]
    pub login_id: Option<String>,
}

#[derive(Deserialize)]
pub struct ChangePasswordRequest {
    #[serde(rename = "userId")]
    pub user_id: String,
    #[serde(rename = "oldPassword")]
    pub old_password: Option<String>,
    #[serde(rename = "newPassword")]
    pub new_password: String,
}

#[derive(Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct StudentProfileResponse {
    pub full_name: String,
    pub login_id: String,
    pub branch: Option<String>,
    pub year: Option<String>,
    pub semester: Option<String>,
    pub dob: Option<chrono::NaiveDate>,
    pub batch_no: Option<String>,
    pub section: Option<String>,
    pub pending_update: Option<bool>,
}

#[derive(Deserialize)]
pub struct ProfileQuery {
    #[serde(rename = "userId")]
    pub user_id: Uuid,
}

#[derive(Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct StudentBasicInfo {
    pub student_id: String,
    pub full_name: String,
    pub branch: Option<String>,
    pub year: Option<String>,
    pub section: Option<String>,
}

#[derive(Deserialize)]
pub struct StudentsQuery {
    pub branch: String,
    pub year: String,
    pub section: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StudentCourse {
    pub id: String,
    pub name: String,
    pub faculty_name: String,
    pub credits: i32,
    pub progress: i32,
    pub subject_type: String,
    pub faculty_email: Option<String>,
    pub faculty_phone: Option<String>,
    pub faculty_department: Option<String>,
    pub status: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ParentProfileResponse {
    pub full_name: String,
    pub phone_number: Option<String>,
    pub email: Option<String>,
    pub student: Option<StudentDetails>,
}

#[derive(Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct StudentDetails {
    pub full_name: String,
    pub login_id: String,
    pub branch: Option<String>,
    pub year: Option<String>,
    pub semester: Option<String>,
    pub batch_no: Option<String>,
}

// Unused seeding structs removed

#[derive(Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct LessonPlanItemResponse {
    pub id: String,
    #[sqlx(rename = "type")]
    #[serde(rename = "type")]
    pub item_type: String,
    pub topic: Option<String>,
    pub text: Option<String>,
    pub sno: Option<String>,
    #[serde(default)] 
    pub completed: Option<bool>, 
    #[serde(rename = "completedAt")]
    pub completed_at: Option<chrono::DateTime<Utc>>,
    pub student_review: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LessonPlanResponse {
    pub percentage: i32,
    pub status: String,
    pub warning: Option<String>,
    pub items: Vec<LessonPlanItemResponse>,
}

#[derive(Deserialize)]
pub struct LessonPlanQuery {
    #[serde(rename = "subjectId")]
    pub subject_id: String,
    #[serde(rename = "userId")]
    pub user_id: Option<String>,
    pub section: Option<String>,
}

#[derive(Deserialize)]
pub struct LessonPlanFeedbackRequest {
    #[serde(rename = "lesson_plan_id")]
    pub lesson_plan_id: String,
    #[serde(rename = "user_id")]
    pub user_id: Uuid,
    pub rating: i32,
    #[serde(rename = "issue_type")]
    pub issue_type: String,
    pub comment: String,
}

#[derive(Deserialize)]
pub struct DeleteFeedbackQuery {
    #[serde(rename = "userId")]
    pub user_id: Uuid,
}

#[derive(Serialize, FromRow)]
pub struct LessonPlanFeedbackResponse {
    pub id: Uuid,
    #[serde(rename = "userId")]
    pub user_id: Uuid,
    pub rating: i32,
    #[sqlx(rename = "issue_type")]
    #[serde(rename = "issueType")]
    pub issue_type: String,
    pub comment: String,
    #[sqlx(rename = "created_at")]
    #[serde(rename = "createdAt")]
    pub created_at: DateTime<Utc>,
    #[sqlx(rename = "student_name")]
    #[serde(rename = "studentName")]
    pub student_name: String,
    pub reply: Option<String>,
    #[sqlx(rename = "replied_at")]
    #[serde(rename = "repliedAt")]
    pub replied_at: Option<DateTime<Utc>>,
}

#[derive(Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct StudentFeedbacksResponse {
    pub id: Uuid,
    pub rating: i32,
    #[sqlx(rename = "issue_type")]
    #[serde(rename = "issueType")]
    pub issue_type: String,
    pub comment: String,
    #[sqlx(rename = "created_at")]
    #[serde(rename = "createdAt")]
    pub created_at: DateTime<Utc>,
    pub reply: Option<String>,
    #[sqlx(rename = "replied_at")]
    #[serde(rename = "repliedAt")]
    pub replied_at: Option<DateTime<Utc>>,
    
    // Joined fields
    pub topic: Option<String>,
    #[sqlx(rename = "subject_code")]
    #[serde(rename = "subjectCode")]
    pub subject_code: Option<String>, 
    #[sqlx(rename = "subject_name")]
    #[serde(rename = "subjectName")]
    pub subject_name: Option<String>,
}

#[derive(Deserialize)]
pub struct ReplyFeedbackRequest {
    #[serde(rename = "feedbackId")]
    pub feedback_id: Uuid,
    #[serde(rename = "facultyId")]
    pub faculty_id: Uuid,
    pub reply: String,
}

#[derive(Deserialize)]
pub struct GetFeedbackQuery {
    #[serde(rename = "lessonPlanId")]
    pub lesson_plan_id: String,
}

#[derive(Deserialize)]
pub struct MarkCompleteRequest {
    #[serde(rename = "itemId")]
    pub item_id: String,
    pub completed: bool,
    pub section: Option<String>,
}

#[derive(Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct FacultyProfileResponse {
    pub full_name: String,
    pub faculty_id: String,
    pub branch: Option<String>,
    pub email: Option<String>,
    pub phone_number: Option<String>,
    pub experience: Option<String>,
    pub dob: Option<chrono::NaiveDate>,
}

#[derive(Serialize, FromRow)]
pub struct FacultySubjectResponse {
    pub id: String,
    pub name: String,
    pub branch: String,
    pub semester: String,
    pub section: Option<String>,
    pub status: String,
    #[sqlx(rename = "subject_id")] 
    pub subject_id: String,
    #[sqlx(default)]
    pub completion_percentage: i32,
}

#[derive(Deserialize)]
pub struct FacultyQueryParams {
    #[serde(rename = "userId")]
    pub user_id: Uuid,
}

#[derive(Deserialize)]
pub struct AddFacultySubjectRequest {
    #[serde(rename = "userId")]
    pub user_id: Uuid,
    #[serde(rename = "subjectId")]
    pub subject_id: String,
    #[serde(rename = "subjectName")]
    pub subject_name: String,
    pub branch: String,
    pub section: Option<String>,
}

#[derive(Deserialize)]
pub struct RemoveFacultySubjectRequest {
    #[serde(rename = "userId")]
    pub user_id: Uuid,
    #[serde(rename = "subjectId")]
    pub subject_id: String,
    pub section: Option<String>,
}

#[derive(Deserialize)]
pub struct ApproveSubjectRequest {
    #[serde(rename = "notificationId")]
    pub notification_id: Uuid,
    #[serde(rename = "senderId")]
    pub sender_id: String, 
    pub action: String, // "APPROVE" or "REJECT"
}

#[derive(Deserialize, Serialize, Debug, Clone)]
pub struct ProfileUpdateRequestData {
    #[serde(rename = "userId")]
    pub user_id: String,
    
    // Faculty fields (existing)
    #[serde(rename = "fullName")]
    pub full_name: Option<String>,
    #[serde(rename = "phoneNumber")]
    pub phone_number: Option<String>,
    pub email: Option<String>,
    pub experience: Option<String>,
    pub dob: Option<String>,
    #[serde(rename = "facultyId")]
    pub faculty_id: Option<String>,
    pub branch: Option<String>,

    // Student fields (new)
    #[serde(rename = "newFullName")]
    pub new_full_name: Option<String>,
    #[serde(rename = "newStudentId")]
    pub new_student_id: Option<String>,
    #[serde(rename = "newBranch")]
    pub new_branch: Option<String>,
    #[serde(rename = "newYear")]
    pub new_year: Option<String>,
    #[serde(rename = "newSemester")]
    pub new_semester: Option<String>,
    #[serde(rename = "newDob")]
    pub new_dob: Option<String>,
    #[serde(rename = "newBatchNo")]
    pub new_batch_no: Option<String>,
}

#[derive(Deserialize)]
pub struct ApproveProfileChangeRequest {
    #[serde(rename = "notificationId")]
    pub notification_id: Uuid,
    #[serde(rename = "senderId")]
    pub sender_id: String, 
    pub action: String,
}

#[derive(Deserialize, Debug)]
pub struct SubmitAttendanceRequest {
    #[serde(rename = "studentId")]
    pub student_id: String,
    #[serde(rename = "facultyId")]
    pub faculty_id: String,
    pub date: String, // YYYY-MM-DD
    pub status: String, 
    pub session: Option<String>,
}

#[derive(Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct AttendanceRecord {
    pub id: Uuid,
    pub date: chrono::NaiveDate,
    pub status: String,
    pub session: Option<String>, 
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AttendanceSummary {
    pub total_classes: i64,
    pub present_count: i64,
    pub absent_count: i64,
    pub percentage: f64,
    pub history: Vec<AttendanceRecord>,
}

#[derive(Deserialize)]
pub struct AttendanceQuery {
    #[serde(rename = "studentId")]
    pub student_id: String,
}

#[derive(Deserialize)]
pub struct CheckAttendanceQuery {
    pub branch: String,
    pub year: String,
    pub date: String,
    pub session: String,
    pub section: Option<String>,
}

#[derive(Deserialize)]
pub struct ClassRecordQuery {
    pub branch: String,
    pub year: String,
    pub session: String,
    pub date: String,
    pub section: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ClassRecordResponse {
    pub marked: bool,
    pub marked_by: Option<String>,
    pub students: Vec<StudentAttendanceItem>,
}

#[derive(Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct StudentAttendanceItem {
    #[sqlx(rename = "student_id")]
    pub student_id: String,
    #[sqlx(rename = "full_name")]
    pub full_name: String,
    pub status: String,
}

#[derive(Deserialize, Debug)]
pub struct BatchAttendanceRequest {
    pub session: Option<String>,
    pub date: String,
    #[serde(rename = "markedBy")]
    pub marked_by: String, 
    pub records: Vec<BatchRecord>
}

#[derive(Deserialize, Debug)]
pub struct BatchRecord {
    #[serde(rename = "studentId")]
    pub student_id: String, 
    pub status: String
}

#[derive(Deserialize)]
pub struct AttendanceStatsQuery {
    pub branch: String,
    pub date: String,
    pub session: Option<String>,
    pub year: Option<String>,
    pub section: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AttendanceStatsResponse {
    pub total_students: i64,
    pub total_present: i64,
    pub total_absent: i64,
}

#[derive(Deserialize, Serialize, Debug)]
pub struct AttendanceCorrectionItem {
    pub date: String,
    pub session: String,
}

#[derive(Deserialize, Serialize, Debug)]
pub struct AttendanceCorrectionRequestData {
    #[serde(rename = "userId")]
    pub user_id: String,
    pub items: Vec<AttendanceCorrectionItem>,
    pub reason: String,
}

#[derive(Deserialize, Debug)]
pub struct ApproveAttendanceCorrectionData {
    #[serde(rename = "senderId")]
    pub sender_id: Uuid, 
    #[serde(rename = "notificationId")]
    pub notification_id: Option<Uuid>,
    pub action: String, // "APPROVE" or "REJECT"
}

#[derive(Serialize, FromRow)]
pub struct CorrectionRequestHistoryItem {
    pub id: Uuid,
    pub dates: serde_json::Value,
    pub reason: String,
    pub status: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Deserialize)]
pub struct DeleteCorrectionRequestsRequest {
    pub ids: Vec<Uuid>,
}

#[derive(Deserialize)]
pub struct AdminUserQuery {
    pub role: Option<String>,
    pub category: Option<String>, 
    pub search: Option<String>,
    pub branch: Option<String>,
    pub year: Option<String>,
    pub is_approved: Option<bool>,
}

#[derive(Serialize, FromRow)]
pub struct AdminUserDTO {
    pub id: Uuid,
    pub full_name: String,
    pub role: String,
    pub login_id: String,
    pub branch: Option<String>,
    pub year: Option<String>,
    pub is_approved: Option<bool>,
}

#[derive(Serialize)]
pub struct AdminStats {
    pub total_users: i64,
    pub pending_approvals: i64,
    pub total_students: i64,
    pub total_faculty: i64,
}

#[derive(Deserialize)]
pub struct AdminApprovalRequest {
    pub user_id: Uuid,
    pub action: String, // "APPROVE", "REJECT", "DELETE"
}

#[derive(Deserialize)]
pub struct FacultyByBranchQuery {
    pub branch: Option<String>,
}

#[derive(Serialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct FacultyListDTO {
    pub id: uuid::Uuid,
    pub full_name: String,
    pub login_id: String,
    pub email: Option<String>,
    pub phone_number: Option<String>,
    pub experience: Option<String>,
    pub branch: Option<String>,
    pub role: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ForgotPasswordRequest {
    pub login_id: String,
    pub dob: String, // "YYYY-MM-DD"
}

#[derive(Serialize, Debug)]
pub struct ResetResponse {
    pub message: String,
    pub action: String, // "request_sent", "otp_sent", "admin_contact", "error"
}

#[derive(Deserialize)]
pub struct CheckUserQuery {
    #[serde(rename = "loginId")]
    pub login_id: String,
}

#[derive(Deserialize, Debug)]
pub struct CreateStudentRequest {
    #[serde(rename = "fullName")]
    pub full_name: String,
    #[serde(rename = "studentId")]
    pub student_id: String,
    pub branch: String,
    pub year: String,
    pub section: Option<String>,
    pub batch: Option<String>,
    pub semester: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, FromRow)]
pub struct Announcement {
    pub id: Uuid,
    pub title: String,
    pub description: String,
    #[sqlx(rename = "type")]
    #[serde(rename = "type")]
    pub announcement_type: String, 
    pub audience: Vec<String>, 
    pub priority: String,
    pub start_date: DateTime<Utc>,
    pub end_date: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub is_pinned: bool,
    pub attachment_url: Option<String>,
    pub creator_id: Uuid,
}

#[derive(Deserialize, Debug)]
pub struct CreateAnnouncementRequest {
    pub title: String,
    pub description: String,
    #[serde(rename = "type")]
    pub announcement_type: String,
    pub audience: Vec<String>,
    pub priority: String,
    pub start_date: DateTime<Utc>, 
    pub end_date: DateTime<Utc>,   
    #[serde(rename = "isPinned")]
    pub is_pinned: bool,
    #[serde(rename = "creatorId")]
    pub creator_id: String, // Frontend sends string ID
    #[serde(rename = "attachmentUrl")]
    pub attachment_url: Option<String>,
}

#[derive(Deserialize)]
pub struct GetAnnouncementsQuery {
    #[serde(rename = "userId")]
    pub user_id: Option<String>,
    pub role: Option<String>,
}
