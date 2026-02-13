use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
    response::IntoResponse,
};
use uuid::Uuid;
use chrono::Utc;
use crate::models::{AppState, Announcement, CreateAnnouncementRequest, GetAnnouncementsQuery};
use serde_json::json;
use sqlx::Row; // For manual mapping if needed, but FromRow derives should work

pub async fn create_announcement_handler(
    State(data): State<AppState>,
    Json(body): Json<CreateAnnouncementRequest>,
) -> impl IntoResponse {
    let new_id = Uuid::new_v4();
    
    // Parse creator_id
    let creator_uuid = match Uuid::parse_str(&body.creator_id) {
        Ok(id) => id,
        Err(_) => return (StatusCode::BAD_REQUEST, Json(json!({"message": "Invalid Creator ID"}))).into_response(),
    };

    // Use query_as instead of query_as! to avoid macro expansion issues without live DB connection during this edit context
    // We need to match the struct fields
    let result = sqlx::query_as::<_, Announcement>(
        "INSERT INTO announcements (id, title, description, type, audience, priority, start_date, end_date, is_pinned, attachment_url, creator_id, created_at) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) 
         RETURNING *"
    )
    .bind(new_id)
    .bind(body.title)
    .bind(body.description)
    .bind(body.announcement_type)
    .bind(&body.audience)
    .bind(body.priority)
    .bind(body.start_date)
    .bind(body.end_date)
    .bind(body.is_pinned)
    .bind(body.attachment_url)
    .bind(creator_uuid)
    .bind(Utc::now())
    .fetch_one(&data.pool)
    .await;

    match result {
        Ok(announcement) => {
            (StatusCode::CREATED, Json(json!({"message": "Announcement created successfully", "announcement": announcement}))).into_response()
        }
        Err(e) => {
            eprintln!("Failed to create announcement: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": "Failed to create announcement"}))).into_response()
        }
    }
}

pub async fn get_announcements_handler(
    State(data): State<AppState>,
    Query(_params): Query<GetAnnouncementsQuery>,
) -> impl IntoResponse {
    // If user_id/role is provided, we could filter. 
    // For now, let's fetch strictly relevant announcements or all active ones.
    
    // Logic: 
    // 1. Fetch all announcements where end_date >= NOW() (Active)
    // 2. Sort by is_pinned DESC, created_at DESC
    
    let result = sqlx::query_as::<_, Announcement>(
        "SELECT * FROM announcements WHERE end_date >= NOW() ORDER BY is_pinned DESC, created_at DESC"
    )
    .fetch_all(&data.pool)
    .await;

    match result {
        Ok(announcements) => (StatusCode::OK, Json(announcements)).into_response(),
        Err(e) => {
             eprintln!("Failed to fetch announcements: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": "Failed to fetch announcements"}))).into_response()
        }
    }
}
