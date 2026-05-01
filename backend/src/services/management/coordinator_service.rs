use sqlx::{PgPool};
use axum::http::StatusCode;
use uuid::Uuid;
use crate::models::{Announcement, CreateAnnouncementRequest, GetAnnouncementsQuery, DepartmentTiming};
use crate::repositories::management::coordinator_repository;

pub async fn create_announcement(pool: &PgPool, body: CreateAnnouncementRequest) -> Result<Announcement, (StatusCode, String)> {
    let creator_uuid = Uuid::parse_str(&body.creator_id).map_err(|_| (StatusCode::BAD_REQUEST, "Invalid Creator ID".to_string()))?;

    let announcement = coordinator_repository::insert_announcement(
        pool, 
        Uuid::new_v4(), 
        &body.title, 
        &body.description, 
        &body.announcement_type, 
        &body.audience, 
        &body.priority, 
        body.start_date, 
        body.end_date, 
        body.is_pinned, 
        body.attachment_url.as_deref(), 
        creator_uuid
    ).await.map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

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
                "Incharge" | "Incharges" => (Some("COORDINATOR_RECIPIENT"), false),
                _ => (None, false),
            };
            if is_broadcast || recipient_label.is_some() {
                let _ = coordinator_repository::insert_notification(pool, "ANNOUNCEMENT", &msg, &body.creator_id, recipient_label).await;
            }
        }
    }
    Ok(announcement)
}

pub async fn get_announcements(pool: &PgPool, params: GetAnnouncementsQuery) -> Result<Vec<Announcement>, StatusCode> {
    match params.role.as_deref() {
        Some("Admin") | Some("Principal") | Some("Coordinator") | Some("HOD") => {
            coordinator_repository::find_announcements_admin(pool).await
        },
        Some(role) => {
            let role_plural = format!("{}s", role);
            coordinator_repository::find_announcements_by_role(pool, role, &role_plural).await
        },
        None => {
            coordinator_repository::find_announcements_public(pool).await
        }
    }.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_all_departments(pool: &PgPool) -> Result<Vec<DepartmentTiming>, StatusCode> {
    coordinator_repository::find_all_department_timings(pool)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn delete_department(pool: &PgPool, branch_name: &str) -> Result<u64, StatusCode> {
    coordinator_repository::delete_department_timing(pool, branch_name)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn delete_announcement(pool: &PgPool, announcement_id: Uuid) -> Result<u64, StatusCode> {
    coordinator_repository::delete_announcement(pool, announcement_id)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn pin_announcement(pool: &PgPool, announcement_id: Uuid, is_pinned: bool) -> Result<u64, StatusCode> {
    coordinator_repository::update_announcement_pin(pool, announcement_id, is_pinned)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_all_branches_syllabus_progress(pool: &PgPool, course_id: &str) -> Result<Vec<serde_json::Value>, StatusCode> {
    let branches = coordinator_repository::find_all_branches(pool).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let mut results = Vec::new();
    for branch_name in branches {
        let mut total_avg = 0.0;
        let years = vec!["1st Year", "2nd Year", "3rd Year"];
        let mut year_data = Vec::new();
        for year in &years {
            let progress = crate::services::management::hod_service::calculate_year_progress(pool, &branch_name, course_id, year).await.unwrap_or(0);
            total_avg += progress as f64;
            year_data.push(serde_json::json!({ "year": year.to_string(), "percentage": progress }));
        }
        results.push(serde_json::json!({ "branch": branch_name, "overallPercentage": ((total_avg / 3.0) as f64).round() as i32, "years": year_data }));
    }
    Ok(results)
}
