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

    let result = sqlx::query_as::<_, Announcement>(
        "INSERT INTO announcements (id, title, description, type, audience, priority, start_date, end_date, is_pinned, attachment_url, creator_id, created_at) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) 
         RETURNING *"
    )
    .bind(new_id)
    .bind(&body.title)
    .bind(&body.description)
    .bind(&body.announcement_type)
    .bind(&body.audience)
    .bind(&body.priority)
    .bind(body.start_date)
    .bind(body.end_date)
    .bind(body.is_pinned)
    .bind(&body.attachment_url)
    .bind(creator_uuid)
    .bind(Utc::now())
    .fetch_one(&data.pool)
    .await;

    match result {
        Ok(announcement) => {
            // Send In-App Notifications if requested
            if body.send_in_app {
                let msg = format!("{}: {}", body.title, body.description);
                if msg.len() > 200 {
                    // Truncate if too long for notification summary
                    // msg = format!("{}...", &msg[..197]);
                }
                
                let mut global_broadcast_sent = false;
                for audience_role in &body.audience {
                    let recipient_label = match audience_role.as_str() {
                        "Students" | "Faculty" | "All" => {
                            if global_broadcast_sent { continue; }
                            global_broadcast_sent = true;
                            None
                        },
                        "HODs" => Some("HOD_RECIPIENT"),
                        "Principal" => Some("PRINCIPAL_RECIPIENT"),
                        "Coordinator" => Some("COORDINATOR_RECIPIENT"),
                        _ => None,
                    };

                    // Insert notification
                    let _ = sqlx::query(
                        "INSERT INTO notifications (type, message, sender_id, recipient_id, status, created_at) 
                         VALUES ($1, $2, $3, $4, 'UNREAD', $5)"
                    )
                    .bind("ANNOUNCEMENT")
                    .bind(&msg)
                    .bind(&body.creator_id)
                    .bind(recipient_label)
                    .bind(Utc::now())
                    .execute(&data.pool)
                    .await;
                }
            }

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

pub async fn get_all_departments_handler(
    State(data): State<AppState>,
) -> impl IntoResponse {
    let result = sqlx::query_as::<_, crate::models::DepartmentTiming>(
        "SELECT * FROM department_timings"
    )
    .fetch_all(&data.pool)
    .await;

    match result {
        Ok(departments) => (StatusCode::OK, Json(departments)).into_response(),
        Err(e) => {
            eprintln!("Failed to fetch departments: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": "Failed to fetch departments"}))).into_response()
        }
    }
}

pub async fn delete_department_handler(
    State(data): State<AppState>,
    Json(payload): Json<serde_json::Value>,
) -> impl IntoResponse {
    let branch = payload.get("branch").and_then(|v| v.as_str());

    if let Some(branch_name) = branch {
        let result = sqlx::query("DELETE FROM department_timings WHERE branch = $1")
            .bind(branch_name)
            .execute(&data.pool)
            .await;

        match result {
            Ok(res) => {
                if res.rows_affected() > 0 {
                    (StatusCode::OK, Json(json!({"message": "Department deleted successfully"}))).into_response()
                } else {
                    (StatusCode::NOT_FOUND, Json(json!({"message": "Department not found"}))).into_response()
                }
            },
            Err(e) => {
                eprintln!("Failed to delete department: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": "Failed to delete department"}))).into_response()
            }
        }
    } else {
        (StatusCode::BAD_REQUEST, Json(json!({"message": "Branch name is required"}))).into_response()
    }
}

pub async fn delete_announcement_handler(
    State(data): State<AppState>,
    Json(payload): Json<serde_json::Value>,
) -> impl IntoResponse {
    let id_str = payload.get("id").and_then(|v| v.as_str());

    if let Some(id_str) = id_str {
        if let Ok(announcement_id) = Uuid::parse_str(id_str) {
            let result = sqlx::query("DELETE FROM announcements WHERE id = $1")
                .bind(announcement_id)
                .execute(&data.pool)
                .await;

            match result {
                Ok(res) => {
                    if res.rows_affected() > 0 {
                        (StatusCode::OK, Json(json!({"message": "Announcement deleted successfully"}))).into_response()
                    } else {
                        (StatusCode::NOT_FOUND, Json(json!({"message": "Announcement not found"}))).into_response()
                    }
                },
                Err(e) => {
                    eprintln!("Failed to delete announcement: {:?}", e);
                    (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": "Failed to delete announcement"}))).into_response()
                }
            }
        } else {
            (StatusCode::BAD_REQUEST, Json(json!({"message": "Invalid announcement ID format"}))).into_response()
        }
    } else {
        (StatusCode::BAD_REQUEST, Json(json!({"message": "Announcement ID is required"}))).into_response()
    }
}

pub async fn pin_announcement_handler(
    State(data): State<AppState>,
    Json(payload): Json<serde_json::Value>,
) -> impl IntoResponse {
    let id_str = payload.get("id").and_then(|v| v.as_str());
    let is_pinned = payload.get("isPinned").and_then(|v| v.as_bool()).unwrap_or(false);

    if let Some(id_str) = id_str {
        if let Ok(announcement_id) = Uuid::parse_str(id_str) {
            let result = sqlx::query("UPDATE announcements SET is_pinned = $1 WHERE id = $2")
                .bind(is_pinned)
                .bind(announcement_id)
                .execute(&data.pool)
                .await;

            match result {
                Ok(res) => {
                    if res.rows_affected() > 0 {
                        (StatusCode::OK, Json(json!({"message": "Announcement pinned status updated successfully"}))).into_response()
                    } else {
                        (StatusCode::NOT_FOUND, Json(json!({"message": "Announcement not found"}))).into_response()
                    }
                },
                Err(e) => {
                    eprintln!("Failed to update announcement pin status: {:?}", e);
                    (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": "Failed to update announcement pin status"}))).into_response()
                }
            }
        } else {
            (StatusCode::BAD_REQUEST, Json(json!({"message": "Invalid announcement ID format"}))).into_response()
        }
    } else {
        (StatusCode::BAD_REQUEST, Json(json!({"message": "Announcement ID is required"}))).into_response()
    }
}
