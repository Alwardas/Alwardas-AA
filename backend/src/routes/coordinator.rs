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
// use sqlx::Row; // Removed to fix warning

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
                
                for audience_role in &body.audience {
                    let (recipient_label, is_broadcast) = match audience_role.as_str() {
                        "All" => (None, true),
                        "Students" => (Some("STUDENT_RECIPIENT"), false),
                        "Faculty" => (Some("FACULTY_RECIPIENT"), false),
                        "Parents" => (Some("PARENT_RECIPIENT"), false),
                        "HODs" => (Some("HOD_RECIPIENT"), false),
                        "Principal" => (Some("PRINCIPAL_RECIPIENT"), false),
                        "Coordinator" => (Some("COORDINATOR_RECIPIENT"), false),
                        "Incharge" | "Incharges" => (Some("COORDINATOR_RECIPIENT"), false), // Incharges usually map to coordinator notifications in this app
                        _ => (None, false), // Custom filter strings like "Branches: CME" should not trigger a new notification row
                    };

                    // Only insert if it's 'All' or we found a specific recipient label
                    if is_broadcast || recipient_label.is_some() {
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
    Query(params): Query<GetAnnouncementsQuery>,
) -> impl IntoResponse {
    let (query, binds_needed) = match params.role.as_deref() {
        Some("Admin") | Some("Principal") | Some("Coordinator") | Some("HOD") => {
            // High-privileged roles see everything
            ("SELECT * FROM announcements WHERE end_date >= NOW() ORDER BY is_pinned DESC, created_at DESC", 0)
        }
        Some(role) => {
            // Specific role provided: Filter by All, Role, or Role+s
            ("SELECT * FROM announcements WHERE end_date >= NOW() AND ('All' = ANY(audience) OR $1 = ANY(audience) OR $2 = ANY(audience)) ORDER BY is_pinned DESC, created_at DESC", 2)
        }
        None => {
            // No role provided: Only show public announcements
            ("SELECT * FROM announcements WHERE end_date >= NOW() AND 'All' = ANY(audience) ORDER BY is_pinned DESC, created_at DESC", 0)
        }
    };

    let result = if binds_needed == 2 {
        let role = params.role.as_ref().unwrap();
        let role_plural = format!("{}s", role);
        sqlx::query_as::<_, Announcement>(query)
            .bind(role)
            .bind(role_plural)
            .fetch_all(&data.pool)
            .await
    } else {
        sqlx::query_as::<_, Announcement>(query)
            .fetch_all(&data.pool)
            .await
    };

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
pub async fn get_all_branches_syllabus_progress_handler(
    State(data): State<AppState>,
    Query(params): Query<serde_json::Value>,
) -> impl IntoResponse {
    let course_id = params.get("courseId").and_then(|v| v.as_str()).unwrap_or("C-23");
    
    // 1. Fetch all branches from both departments table and users table to ensure completeness
    let branches_res = sqlx::query_scalar::<_, String>(
        "SELECT DISTINCT branch FROM (
            SELECT branch FROM department_timings
            UNION
            SELECT branch FROM sections
            UNION
            SELECT branch FROM users WHERE branch IS NOT NULL AND branch != ''
        ) as combined_branches ORDER BY branch ASC"
    )
    .fetch_all(&data.pool)
    .await;

    let branches = match branches_res {
        Ok(b) => b,
        Err(e) => {
            eprintln!("Failed to fetch branches: {:?}", e);
            return (StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"message": "Failed to fetch branches"}))).into_response();
        }
    };

    use futures::future::join_all;

    let mut branch_futures = Vec::new();

    for branch_name in branches {
        let pool = data.pool.clone();
        let b_name = branch_name.clone();
        let c_id = course_id.to_string();

        branch_futures.push(tokio::spawn(async move {
            let mut total_avg = 0.0;
            let years = vec!["1st Year", "2nd Year", "3rd Year"];
            let mut year_data = Vec::new();
            
            for year in &years {
                let progress = crate::routes::hod::calculate_year_progress(&pool, &b_name, &c_id, year).await.unwrap_or(0);
                total_avg += progress as f64;
                year_data.push(json!({
                    "year": year.to_string(),
                    "percentage": progress
                }));
            }

            let overall = (total_avg / 3.0).round() as i32;

            json!({
                "branch": b_name,
                "overallPercentage": overall,
                "years": year_data
            })
        }));
    }

    let branch_results = join_all(branch_futures).await;
    let result: Vec<serde_json::Value> = branch_results.into_iter()
        .filter_map(|r| r.ok())
        .collect();

    (StatusCode::OK, Json(result)).into_response()
}
