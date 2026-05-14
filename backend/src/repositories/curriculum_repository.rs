use sqlx::{PgPool, Postgres};
use uuid::Uuid;
use crate::models::curriculum::{CurriculumProgressRow, UpdateProgressRequest, SubmitFeedbackRequest};

pub async fn get_progress(
    pool: &PgPool,
    subject_code: &str,
    branch: &str,
    section: &str,
    year: &str,
) -> Result<Vec<CurriculumProgressRow>, sqlx::Error> {
    sqlx::query_as::<Postgres, CurriculumProgressRow>(
        "SELECT * FROM curriculum_progress 
         WHERE subject_code = $1 AND branch = $2 AND section = $3 AND year = $4"
    )
    .bind(subject_code)
    .bind(branch)
    .bind(section)
    .bind(year)
    .fetch_all(pool)
    .await
}

pub async fn upsert_progress(
    pool: &PgPool,
    req: UpdateProgressRequest,
) -> Result<u64, sqlx::Error> {
    sqlx::query(
        "INSERT INTO curriculum_progress (
            topic_id, subject_code, faculty_id, branch, section, year, semester, 
            assigned_date, completed_date, status, remarks
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         ON CONFLICT (topic_id, subject_code, branch, section, year, semester)
         DO UPDATE SET 
            faculty_id = EXCLUDED.faculty_id,
            assigned_date = EXCLUDED.assigned_date,
            completed_date = EXCLUDED.completed_date,
            status = EXCLUDED.status,
            remarks = EXCLUDED.remarks,
            updated_at = NOW()"
    )
    .bind(&req.topic_id)
    .bind(&req.subject_code)
    .bind(req.faculty_id)
    .bind(&req.branch)
    .bind(&req.section)
    .bind(&req.year)
    .bind(req.semester)
    .bind(req.assigned_date)
    .bind(req.completed_date)
    .bind(&req.status)
    .bind(&req.remarks)
    .execute(pool)
    .await
    .map(|r| r.rows_affected())
}

pub async fn insert_feedback(
    pool: &PgPool,
    student_id: Uuid,
    req: SubmitFeedbackRequest,
) -> Result<u64, sqlx::Error> {
    // Determine understood from rating or issue_type if not provided
    let understood = req.understood.unwrap_or_else(|| {
        if let Some(rating) = req.rating {
            rating >= 4
        } else if let Some(ref it) = req.issue_type {
            it == "DONE"
        } else {
            true
        }
    });

    sqlx::query(
        "INSERT INTO student_curriculum_feedback (
            topic_id, subject_code, student_id, understood, rating, issue_type, comment
         ) VALUES ($1, $2, $3, $4, $5, $6, $7)"
    )
    .bind(&req.topic_id)
    .bind(&req.subject_code)
    .bind(student_id)
    .bind(understood)
    .bind(req.rating)
    .bind(&req.issue_type)
    .bind(&req.comment)
    .execute(pool)
    .await
    .map(|r| r.rows_affected())
}

pub async fn get_topic_feedback_stats(
    pool: &PgPool,
    subject_code: &str,
) -> Result<Vec<(String, i32, f64)>, sqlx::Error> {
    sqlx::query_as::<_, (String, i32, f64)>(
        "SELECT topic_id, COUNT(*)::INT as count, 
         AVG(CASE WHEN (rating >= 4 OR issue_type = 'DONE' OR understood = TRUE) THEN 100 ELSE 0 END)::FLOAT as understood_percentage
         FROM student_curriculum_feedback
         WHERE subject_code = $1
         GROUP BY topic_id"
    )
    .bind(subject_code)
    .fetch_all(pool)
    .await
}
