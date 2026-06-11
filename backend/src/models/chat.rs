use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};

#[derive(Deserialize, Debug)]
pub struct ChatSearchQuery {
    pub erp_id: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ChatUserSearchResult {
    pub full_name: String,
    pub role: String,
    pub login_id: String,
    pub branch: Option<String>,
    pub section: Option<String>,
    pub is_connected: bool,
    pub connection_status: Option<String>, // "PENDING", "ACCEPTED", etc.
}

#[derive(Deserialize, Debug)]
pub struct ChatRequestPayload {
    pub sender_id: String, // Current user login_id
    pub receiver_id: String,
    pub optional_message: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, sqlx::FromRow, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ChatRequestResponse {
    pub id: Uuid,
    pub sender_id: String,
    pub sender_name: String,
    pub sender_role: String,
    pub sender_branch: Option<String>,
    pub receiver_id: String,
    pub receiver_name: String,
    pub receiver_role: String,
    pub receiver_branch: Option<String>,
    pub optional_message: Option<String>,
    pub status: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Deserialize, Debug)]
pub struct RespondRequestPayload {
    pub user_id: String, // Current user login_id to check permission
    pub action: String, // "ACCEPTED" or "REJECTED"
}

#[derive(Deserialize, Debug)]
pub struct SendMessagePayload {
    pub sender_id: String,
    pub receiver_id: String,
    pub content: String,
    pub message_type: String, // "TEXT", "VOICE", "IMAGE", "FILE", "ERP_DOC"
    pub attachment_url: Option<String>,
    pub attachment_name: Option<String>,
    pub attachment_size: Option<String>,
    pub reply_to_id: Option<Uuid>,
    pub reply_to_content: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, sqlx::FromRow, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ChatMessageResponse {
    pub id: Uuid,
    pub sender_id: String,
    pub receiver_id: String,
    pub content: String,
    pub message_type: String,
    pub attachment_url: Option<String>,
    pub attachment_name: Option<String>,
    pub attachment_size: Option<String>,
    pub reply_to_id: Option<Uuid>,
    pub reply_to_content: Option<String>,
    pub is_starred: bool,
    pub is_deleted_for_everyone: bool,
    pub created_at: DateTime<Utc>,
    #[sqlx(default)]
    pub sender_name: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ConversationResponse {
    pub id: String, // login_id or group_id
    pub name: String,
    pub role: Option<String>,
    pub branch: Option<String>,
    pub section: Option<String>,
    pub is_group: bool,
    pub last_message: Option<String>,
    pub last_message_time: Option<DateTime<Utc>>,
    pub unread_count: i32,
    pub description: Option<String>,
    pub icon_url: Option<String>,
}

#[derive(Deserialize, Debug)]
pub struct CreateGroupPayload {
    pub creator_id: String,
    pub name: String,
    pub description: Option<String>,
    pub icon_url: Option<String>,
    pub members: Vec<String>, // login_ids
}

#[derive(Deserialize, Debug)]
pub struct ChatBlockPayload {
    pub user_id: String, // current user login_id
    pub blocked_id: String,
    pub action: String, // "BLOCK" or "UNBLOCK"
}
