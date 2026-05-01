use sqlx::{PgPool, Postgres, Row};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use serde_json;
use crate::models::{
    StudentProfileResponse, StudentCourse, LessonPlanItemResponse, LessonPlanFeedbackResponse,
    StudentFeedbacksResponse, AttendanceRecord, CorrectionRequestHistoryItem
};

pub async fn find_profile_by_id(pool: &PgPool, user_uuid: Uuid) -> Result<Option<StudentProfileResponse>, sqlx::Error> {
    sqlx::query_as::<Postgres, StudentProfileResponse>(
        "SELECT 
            u.full_name, u.login_id, u.branch, u.year, u.semester, u.dob, u.batch_no, u.section, u.phone_number, u.email,
            EXISTS(SELECT 1 FROM profile_update_requests WHERE user_id = u.id AND status = 'PENDING') as pending_update,
            COALESCE(p1.full_name, p2.full_name) as parent_name,
            COALESCE(p1.phone_number, p2.phone_number) as parent_phone,
            COALESCE(p1.email, p2.email) as parent_email
         FROM users u 
         LEFT JOIN parent_student ps ON u.login_id = ps.student_id
         LEFT JOIN users p1 ON ps.parent_id = p1.login_id AND p1.role = 'Parent'
         LEFT JOIN users p2 ON (CASE WHEN u.login_id NOT LIKE 'P-%' THEN 'P-' || u.login_id ELSE u.login_id END) = p2.login_id AND p2.role = 'Parent'
         WHERE u.id = $1"
    )
    .bind(user_uuid)
    .fetch_optional(pool)
    .await
}

pub async fn delete_pending_update_requests(executor: &mut sqlx::Transaction<'_, Postgres>, user_uuid: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM profile_update_requests WHERE user_id = $1 AND status = 'PENDING'")
        .bind(user_uuid)
        .execute(&mut **executor)
        .await
        .map(|r| r.rows_affected())
}

pub async fn insert_profile_update_request(executor: &mut sqlx::Transaction<'_, Postgres>, user_uuid: Uuid, json_data: serde_json::Value) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO profile_update_requests (user_id, new_data, status) VALUES ($1, $2, 'PENDING')")
        .bind(user_uuid)
        .bind(json_data)
        .execute(&mut **executor)
        .await
        .map(|r| r.rows_affected())
}

pub async fn get_user_branch(executor: &mut sqlx::Transaction<'_, Postgres>, user_uuid: Uuid) -> Result<Option<String>, sqlx::Error> {
    sqlx::query_scalar("SELECT branch FROM users WHERE id = $1")
        .bind(user_uuid)
        .fetch_optional(&mut **executor)
        .await
}

pub async fn insert_notification(executor: &mut sqlx::Transaction<'_, Postgres>, n_type: &str, message: &str, sender_id: &str, branch: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO notifications (type, message, sender_id, branch, status) VALUES ($1, $2, $3, $4, 'UNREAD')")
        .bind(n_type)
        .bind(message)
        .bind(sender_id)
        .bind(branch)
        .execute(&mut **executor)
        .await
        .map(|r| r.rows_affected())
}

pub async fn get_student_basics(pool: &PgPool, user_uuid: Uuid) -> Result<Option<(Option<String>, Option<String>, Option<String>, Option<String>, String)>, sqlx::Error> {
    sqlx::query("SELECT branch, year, semester, section, login_id FROM users WHERE id = $1")
        .bind(user_uuid)
        .fetch_optional(pool)
        .await
        .map(|opt| opt.map(|r| (
            r.get("branch"),
            r.get("year"),
            r.get("semester"),
            r.get("section"),
            r.get("login_id")
        )))
}

pub async fn find_subjects_by_branch_and_semester(pool: &PgPool, branch: &str, semester: &str, section: &str) -> Result<Vec<(String, String, String, Option<String>, Option<String>, Option<String>, Option<String>)>, sqlx::Error> {
    sqlx::query(
        r#"
        SELECT 
            s.id, s.name, s.type as subject_type,
            COALESCE(u.full_name, s.faculty_name, 'TBA') as resolved_faculty_name,
            u.email as faculty_email,
            u.phone_number as faculty_phone,
            u.branch as faculty_department
        FROM subjects s
        LEFT JOIN faculty_subjects fs ON s.id = fs.subject_id AND fs.branch = s.branch AND fs.status = 'APPROVED' AND fs.section = $3
        LEFT JOIN users u ON fs.user_id = u.id
        WHERE s.branch = $1 AND s.semester = $2
        ORDER BY s.id ASC
        "#
    )
    .bind(branch)
    .bind(semester)
    .bind(section)
    .fetch_all(pool)
    .await
    .map(|rows| rows.into_iter().map(|r| (
        r.get("id"),
        r.get("name"),
        r.get("subject_type"),
        r.get("resolved_faculty_name"),
        r.get("faculty_email"),
        r.get("faculty_phone"),
        r.get("faculty_department")
    )).collect())
}

pub async fn count_lesson_plan_items(pool: &PgPool, subject_id: &str) -> Result<i64, sqlx::Error> {
    sqlx::query_scalar("SELECT COUNT(*) FROM lesson_plan_items WHERE subject_id = $1")
        .bind(subject_id)
        .fetch_one(pool)
        .await
}

pub async fn count_completed_lesson_plan_items(pool: &PgPool, subject_id: &str, section: &str) -> Result<i64, sqlx::Error> {
    sqlx::query_scalar("SELECT COUNT(*) FROM lesson_plan_items lpi JOIN lesson_plan_progress lpp ON lpi.id = lpp.item_id WHERE lpi.subject_id = $1 AND lpp.section = $2 AND lpp.completed = TRUE")
        .bind(subject_id)
        .bind(section)
        .fetch_one(pool)
        .await
}

pub async fn get_lesson_plan_items(pool: &PgPool, subject_id: &str, section: &str, branch: Option<&str>) -> Result<Vec<LessonPlanItemResponse>, sqlx::Error> {
    sqlx::query_as::<Postgres, LessonPlanItemResponse>(
        r#"
        SELECT 
            lpi.id::TEXT as id, 
            lpi.type, 
            lpi.topic, 
            lpi.text, 
            lpi.sno, 
            COALESCE(lpp.completed, FALSE) as completed,
            lpp.completed_date as completed_at,
            lpi.student_review,
            ls.schedule_date as scheduled_date
        FROM lesson_plan_items lpi
        LEFT JOIN lesson_plan_progress lpp ON lpi.id = lpp.item_id AND (TRIM(lpp.section) = TRIM($2) OR $2 IS NULL)
        LEFT JOIN lesson_schedule ls ON lpi.id = ls.topic_id AND (TRIM(ls.section) = TRIM($2) OR $2 IS NULL) AND (ls.branch = $3 OR $3 IS NULL)
        WHERE TRIM(lpi.subject_id) ILIKE TRIM($1)
        ORDER BY lpi.order_index ASC
        "#
    )
    .bind(subject_id)
    .bind(section)
    .bind(branch)
    .fetch_all(pool)
    .await
}

pub async fn insert_lesson_plan_feedback(pool: &PgPool, lesson_id: &str, user_id: Uuid, rating: i32, issue_type: &str, comment: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO lesson_plan_feedback (lesson_plan_item_id, user_id, rating, issue_type, comment) VALUES ($1, $2, $3, $4, $5)")
        .bind(lesson_id).bind(user_id).bind(rating).bind(issue_type).bind(comment)
        .execute(pool).await.map(|r| r.rows_affected())
}

pub async fn get_feedback_owner_and_date(pool: &PgPool, feedback_id: Uuid) -> Result<Option<(Uuid, DateTime<Utc>)>, sqlx::Error> {
    sqlx::query_as("SELECT user_id, created_at FROM lesson_plan_feedback WHERE id = $1")
        .bind(feedback_id).fetch_optional(pool).await
}

pub async fn delete_lesson_plan_feedback(pool: &PgPool, feedback_id: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM lesson_plan_feedback WHERE id = $1").bind(feedback_id).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn get_lesson_plan_feedback(pool: &PgPool, lesson_plan_id: &str) -> Result<Vec<LessonPlanFeedbackResponse>, sqlx::Error> {
    sqlx::query_as::<Postgres, LessonPlanFeedbackResponse>(
        "SELECT lpf.id, lpf.user_id, lpf.rating, lpf.issue_type, lpf.comment, lpf.created_at, lpf.reply, lpf.replied_at, COALESCE(u.full_name, 'Unknown Student') as student_name FROM lesson_plan_feedback lpf LEFT JOIN users u ON lpf.user_id = u.id WHERE lpf.lesson_plan_item_id = $1 ORDER BY lpf.created_at DESC"
    )
    .bind(lesson_plan_id).fetch_all(pool).await
}

pub async fn get_student_all_feedbacks(pool: &PgPool, user_uuid: Uuid) -> Result<Vec<StudentFeedbacksResponse>, sqlx::Error> {
    sqlx::query_as::<Postgres, StudentFeedbacksResponse>(
        "SELECT lpf.id, lpf.rating, lpf.issue_type, lpf.comment, lpf.created_at, lpf.reply, lpf.replied_at, lpi.topic, s.id as subject_code, s.name as subject_name FROM lesson_plan_feedback lpf LEFT JOIN lesson_plan_items lpi ON lpf.lesson_plan_item_id = lpi.id LEFT JOIN subjects s ON lpi.subject_id = s.id::text WHERE lpf.user_id = $1 ORDER BY lpf.created_at DESC"
    )
    .bind(user_uuid).fetch_all(pool).await
}

pub async fn get_attendance_history(pool: &PgPool, student_uuid: Uuid) -> Result<Vec<AttendanceRecord>, sqlx::Error> {
    sqlx::query_as::<Postgres, AttendanceRecord>("SELECT id, date, status, session FROM attendance WHERE student_uuid = $1 ORDER BY date DESC, session ASC").bind(student_uuid).fetch_all(pool).await
}

pub async fn insert_attendance_correction_request(executor: &mut sqlx::Transaction<'_, Postgres>, user_uuid: Uuid, dates_json: serde_json::Value, reason: &str) -> Result<Uuid, sqlx::Error> {
    sqlx::query_scalar::<_, Uuid>("INSERT INTO attendance_correction_requests (user_id, dates, reason, status, created_at) VALUES ($1, $2, $3, 'PENDING', NOW()) RETURNING id")
        .bind(user_uuid).bind(dates_json).bind(reason).fetch_one(&mut **executor).await
}

pub async fn get_attendance_correction_requests(pool: &PgPool, student_uuid: Uuid) -> Result<Vec<CorrectionRequestHistoryItem>, sqlx::Error> {
    sqlx::query_as("SELECT id, dates, reason, status, created_at FROM attendance_correction_requests WHERE user_id = $1 ORDER BY created_at DESC").bind(student_uuid).fetch_all(pool).await
}

pub async fn delete_attendance_correction_requests(pool: &PgPool, ids: Vec<Uuid>) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM attendance_correction_requests WHERE id = ANY($1)").bind(&ids).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn get_subjects_by_semester(pool: &PgPool, branch: &str, semester: &str) -> Result<Vec<(String, String, Option<i32>)>, sqlx::Error> {
    sqlx::query_as("SELECT id, name, credit FROM subjects WHERE branch = $1 AND semester = $2 ORDER BY id ASC").bind(branch).bind(semester).fetch_all(pool).await
}

pub async fn get_student_mark(pool: &PgPool, login_id: &str, semester: &str, subject_name: &str) -> Result<Option<Option<i32>>, sqlx::Error> {
    sqlx::query_scalar("SELECT marks FROM student_marks WHERE student_id = $1 AND semester = $2 AND subject_name = $3")
        .bind(login_id).bind(semester).bind(subject_name).fetch_optional(pool).await
}
