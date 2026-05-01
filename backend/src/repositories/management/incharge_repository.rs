use sqlx::{PgPool, Postgres, Row};
use chrono::NaiveDate;
use serde_json;
use crate::models::{TimetableEntry, ClassPeriodStatus};

pub async fn find_timetable_entry(pool: &PgPool, branch: &str, year: &str, section: &str, day: &str, period_index: i32) -> Result<Option<TimetableEntry>, sqlx::Error> {
    sqlx::query_as::<_, TimetableEntry>(
        r#"
        SELECT 
            t.id, t.faculty_id, t.branch, t.year, t.section, t.day, t.period_index, t.subject, t.subject_code,
            u.full_name as faculty_name, u.email as faculty_email, u.phone_number as faculty_phone, u.branch as faculty_department
        FROM timetable_entries t
        LEFT JOIN users u ON t.faculty_id = u.login_id
        WHERE t.branch = $1 AND t.year = $2 AND t.section = $3 AND t.day = $4 AND t.period_index = $5
        "#
    )
    .bind(branch).bind(year).bind(section).bind(day).bind(period_index)
    .fetch_optional(pool).await
}

pub async fn upsert_class_status(pool: &PgPool, branch: &str, year: &str, section: &str, day: &str, period_index: i32, status_date: NaiveDate, original_subject: &str, original_faculty: &str, actual_subject: Option<&str>, actual_faculty: Option<&str>, status: &str, updated_by: &str) -> Result<u64, sqlx::Error> {
    sqlx::query(
        r#"
        INSERT INTO class_period_status (branch, year, section, day, period_index, status_date, original_subject, original_faculty, actual_subject, actual_faculty, status, updated_by)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        ON CONFLICT (branch, year, section, day, period_index, status_date) DO UPDATE SET
            actual_subject = EXCLUDED.actual_subject, actual_faculty = EXCLUDED.actual_faculty, status = EXCLUDED.status, updated_by = EXCLUDED.updated_by, updated_at = NOW()
        "#
    )
    .bind(branch).bind(year).bind(section).bind(day).bind(period_index).bind(status_date)
    .bind(original_subject).bind(original_faculty).bind(actual_subject).bind(actual_faculty)
    .bind(status).bind(updated_by)
    .execute(pool).await.map(|r| r.rows_affected())
}

pub async fn find_class_statuses(pool: &PgPool, branch: &str, year: &str, section: &str, date: NaiveDate) -> Result<Vec<ClassPeriodStatus>, sqlx::Error> {
    sqlx::query_as::<_, ClassPeriodStatus>("SELECT * FROM class_period_status WHERE branch = $1 AND year = $2 AND section = $3 AND status_date = $4")
        .bind(branch).bind(year).bind(section).bind(date).fetch_all(pool).await
}

pub async fn get_daily_activity_stats(pool: &PgPool, branch: &str, date: NaiveDate) -> Result<(i64, i64, i64, i64), sqlx::Error> {
    let row = sqlx::query("SELECT COUNT(*) as total, COUNT(CASE WHEN status = 'conducted' THEN 1 END) as conducted, COUNT(CASE WHEN status = 'substitute' THEN 1 END) as substitute, COUNT(CASE WHEN status = 'not_conducted' THEN 1 END) as not_conducted FROM class_period_status WHERE branch = $1 AND status_date = $2")
        .bind(branch).bind(date).fetch_one(pool).await?;
    
    Ok((row.get("total"), row.get("conducted"), row.get("substitute"), row.get("not_conducted")))
}

pub async fn find_daily_detail_report(pool: &PgPool, branch: &str, date: NaiveDate, day: &str) -> Result<Vec<serde_json::Value>, sqlx::Error> {
    let rows = sqlx::query(
        r#"
        SELECT t.year, t.section, t.period_index, t.subject, t.faculty_id, u.full_name as original_faculty, s.actual_subject, s.actual_faculty, s.status
        FROM timetable_entries t
        LEFT JOIN users u ON t.faculty_id = u.login_id
        LEFT JOIN class_period_status s ON t.branch = s.branch AND t.year = s.year AND t.section = s.section AND t.day = s.day AND t.period_index = s.period_index AND s.status_date = $2
        WHERE t.branch = $1 AND t.day = $3
        ORDER BY t.year, t.section, t.period_index
        "#
    )
    .bind(branch).bind(date).bind(day).fetch_all(pool).await?;

    Ok(rows.into_iter().map(|row| serde_json::json!({
        "year": row.get::<String, _>("year"), 
        "section": row.get::<String, _>("section"), 
        "periodIndex": row.get::<i32, _>("period_index"), 
        "subject": row.get::<String, _>("subject"), 
        "originalFaculty": row.get::<Option<String>, _>("original_faculty").unwrap_or_else(|| row.get::<String, _>("faculty_id")), 
        "actualSubject": row.get::<Option<String>, _>("actual_subject"), 
        "actualFaculty": row.get::<Option<String>, _>("actual_faculty"), 
        "status": row.get::<Option<String>, _>("status"),
    })).collect())
}
