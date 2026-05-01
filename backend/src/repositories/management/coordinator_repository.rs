use sqlx::{PgPool, Postgres, Row};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use crate::models::{Announcement, DepartmentTiming};

pub async fn insert_announcement(pool: &PgPool, id: Uuid, title: &str, desc: &str, a_type: &str, audience: &[String], priority: &str, start_date: DateTime<Utc>, end_date: DateTime<Utc>, is_pinned: bool, attachment_url: Option<&str>, creator_id: Uuid) -> Result<Announcement, sqlx::Error> {
    sqlx::query_as::<_, Announcement>(
        "INSERT INTO announcements (id, title, description, type, audience, priority, start_date, end_date, is_pinned, attachment_url, creator_id, created_at) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) 
         RETURNING *"
    )
    .bind(id).bind(title).bind(desc).bind(a_type).bind(audience).bind(priority).bind(start_date).bind(end_date).bind(is_pinned).bind(attachment_url).bind(creator_id).bind(Utc::now())
    .fetch_one(pool).await
}

pub async fn insert_notification(pool: &PgPool, n_type: &str, message: &str, sender_id: &str, recipient_label: Option<&str>) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO notifications (type, message, sender_id, recipient_id, status, created_at) VALUES ($1, $2, $3, $4, 'UNREAD', $5)")
        .bind(n_type).bind(message).bind(sender_id).bind(recipient_label).bind(Utc::now()).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn find_announcements_admin(pool: &PgPool) -> Result<Vec<Announcement>, sqlx::Error> {
    sqlx::query_as::<_, Announcement>("SELECT * FROM announcements WHERE end_date >= NOW() ORDER BY is_pinned DESC, created_at DESC").fetch_all(pool).await
}

pub async fn find_announcements_by_role(pool: &PgPool, role: &str, role_plural: &str) -> Result<Vec<Announcement>, sqlx::Error> {
    sqlx::query_as::<_, Announcement>("SELECT * FROM announcements WHERE end_date >= NOW() AND ('All' = ANY(audience) OR $1 = ANY(audience) OR $2 = ANY(audience)) ORDER BY is_pinned DESC, created_at DESC")
        .bind(role).bind(role_plural).fetch_all(pool).await
}

pub async fn find_announcements_public(pool: &PgPool) -> Result<Vec<Announcement>, sqlx::Error> {
    sqlx::query_as::<_, Announcement>("SELECT * FROM announcements WHERE end_date >= NOW() AND 'All' = ANY(audience) ORDER BY is_pinned DESC, created_at DESC").fetch_all(pool).await
}

pub async fn find_all_department_timings(pool: &PgPool) -> Result<Vec<DepartmentTiming>, sqlx::Error> {
    sqlx::query_as::<_, DepartmentTiming>("SELECT * FROM department_timings").fetch_all(pool).await
}

pub async fn delete_department_timing(pool: &PgPool, branch: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM department_timings WHERE branch = $1").bind(branch).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn delete_announcement(pool: &PgPool, id: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM announcements WHERE id = $1").bind(id).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn update_announcement_pin(pool: &PgPool, id: Uuid, is_pinned: bool) -> Result<u64, sqlx::Error> {
    sqlx::query("UPDATE announcements SET is_pinned = $1 WHERE id = $2").bind(is_pinned).bind(id).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn find_all_branches(pool: &PgPool) -> Result<Vec<String>, sqlx::Error> {
    sqlx::query_scalar::<_, String>("SELECT DISTINCT branch FROM (SELECT branch FROM department_timings UNION SELECT branch FROM sections UNION SELECT branch FROM users WHERE branch IS NOT NULL AND branch != '') as combined_branches ORDER BY branch ASC").fetch_all(pool).await
}
