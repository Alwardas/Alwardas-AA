use sqlx::{PgPool, Postgres, Row};
use uuid::Uuid;
use serde_json;
use crate::models::{TimetableEntry};

pub async fn find_hod_departments(pool: &PgPool) -> Result<Vec<String>, sqlx::Error> {
    sqlx::query_scalar(
        "SELECT DISTINCT branch FROM (
            SELECT branch FROM department_timings
            UNION
            SELECT branch FROM sections
            UNION
            SELECT branch FROM users WHERE branch IS NOT NULL AND branch != ''
        ) as combined_branches ORDER BY branch ASC"
    )
    .fetch_all(pool)
    .await
}

pub async fn find_sections_by_branch_and_year(pool: &PgPool, branch: &str, year: &str) -> Result<Vec<String>, sqlx::Error> {
    sqlx::query_scalar("SELECT section_name FROM sections WHERE branch = $1 AND year = $2")
        .bind(branch).bind(year).fetch_all(pool).await
}

pub async fn find_subjects_by_branch_and_year(pool: &PgPool, branch: &str, year: &str) -> Result<Vec<String>, sqlx::Error> {
    sqlx::query_scalar("SELECT name FROM subjects WHERE branch = $1 AND year = $2")
        .bind(branch).bind(year).fetch_all(pool).await
}

pub async fn find_existing_course_subject(pool: &PgPool, branch: &str, year: &str, section: &str, subject_name: &str) -> Result<Option<Uuid>, sqlx::Error> {
    sqlx::query_scalar("SELECT id FROM course_subjects WHERE branch = $1 AND year = $2 AND section = $3 AND subject_name = $4")
        .bind(branch).bind(year).bind(section).bind(subject_name).fetch_optional(pool).await
}

pub async fn insert_course_subject(pool: &PgPool, branch: &str, year: &str, section: &str, subject_name: &str, subject_code: Option<&str>, created_by: &str, course_id: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO course_subjects (branch, year, section, subject_name, subject_code, created_by, course_id) VALUES ($1, $2, $3, $4, $5, $6, $7)")
        .bind(branch).bind(year).bind(section).bind(subject_name).bind(subject_code).bind(created_by).bind(course_id)
        .execute(pool).await.map(|r| r.rows_affected())
}

pub async fn find_added_course_subjects(pool: &PgPool, user_id: &str) -> Result<Vec<serde_json::Value>, sqlx::Error> {
    let rows = sqlx::query("SELECT id, branch, year, section, subject_name, subject_code FROM course_subjects WHERE created_by = $1 ORDER BY subject_code ASC, subject_name ASC")
        .bind(user_id).fetch_all(pool).await?;
    
    Ok(rows.into_iter().map(|row| serde_json::json!({
        "id": row.get::<Uuid, _>("id"),
        "branch": row.get::<String, _>("branch"),
        "year": row.get::<String, _>("year"),
        "section": row.get::<String, _>("section"),
        "subjectName": row.get::<String, _>("subject_name"),
        "subject_id": row.get::<Option<String>, _>("subject_code").unwrap_or_default(),
    })).collect())
}

pub async fn find_all_staff(pool: &PgPool) -> Result<Vec<serde_json::Value>, sqlx::Error> {
    let rows = sqlx::query("SELECT login_id, full_name, role FROM users WHERE role IN ('Faculty', 'HOD', 'Principal', 'Coordinator', 'Incharge') ORDER BY full_name ASC")
        .fetch_all(pool).await?;
    
    Ok(rows.into_iter().map(|row| serde_json::json!({
        "id": row.get::<String, _>("login_id"),
        "name": row.get::<String, _>("full_name"),
        "role": row.get::<String, _>("role")
    })).collect())
}

pub async fn find_class_combos(pool: &PgPool, branch: &str) -> Result<Vec<(String, String)>, sqlx::Error> {
    let mut class_combos: Vec<(String, String)> = sqlx::query_as::<Postgres, (String, String)>(
        "SELECT year, section_name FROM sections WHERE branch = $1 ORDER BY year ASC, section_name ASC"
    )
    .bind(branch).fetch_all(pool).await?;

    if class_combos.is_empty() {
        class_combos = sqlx::query_as::<Postgres, (String, String)>(
            "SELECT DISTINCT year, section FROM users WHERE role = 'Student' AND branch = $1 AND year IS NOT NULL AND section IS NOT NULL ORDER BY year ASC, section ASC"
        )
        .bind(branch).fetch_all(pool).await?;
    }
    Ok(class_combos)
}

pub async fn find_timetable_entries_by_day(pool: &PgPool, branch: &str, day: &str) -> Result<Vec<TimetableEntry>, sqlx::Error> {
    sqlx::query_as::<Postgres, TimetableEntry>(
        r#"
        SELECT 
            t.id, t.faculty_id, t.branch, t.year, t.section, t.day, t.period_index, t.subject, t.subject_code,
            u.full_name as faculty_name, u.email as faculty_email, u.phone_number as faculty_phone, u.branch as faculty_department
        FROM timetable_entries t
        LEFT JOIN users u ON t.faculty_id = u.login_id
        WHERE t.branch = $1 AND t.day = $2
        "#
    )
    .bind(branch).bind(day).fetch_all(pool).await
}

pub async fn find_lab_names_by_branch(pool: &PgPool, branch: &str) -> Result<Vec<String>, sqlx::Error> {
    sqlx::query_scalar::<Postgres, String>(
        "SELECT DISTINCT section FROM timetable_entries WHERE branch = $1 AND year = 'Lab' ORDER BY section ASC"
    )
    .bind(branch).fetch_all(pool).await
}

pub async fn find_sections_with_student_fallback(pool: &PgPool, branch: &str, year: &str) -> Result<Vec<String>, sqlx::Error> {
    let mut sections: Vec<String> = sqlx::query_scalar("SELECT section_name FROM sections WHERE branch = $1 AND year = $2")
        .bind(branch).bind(year).fetch_all(pool).await?;

    if sections.is_empty() {
        let year_pattern = format!("{}%", year.trim());
        sections = sqlx::query_scalar(
            "SELECT DISTINCT section FROM users WHERE role = 'Student' AND branch = $1 AND year LIKE $2 AND section IS NOT NULL ORDER BY section ASC"
        )
        .bind(branch).bind(year_pattern).fetch_all(pool).await?;
    }
    Ok(sections)
}

pub async fn find_subjects_by_semester_variations(pool: &PgPool, branch: &str, course_id: Option<&str>, variations: Vec<String>) -> Result<Vec<(String, String)>, sqlx::Error> {
    sqlx::query(
        "SELECT id, name FROM subjects 
         WHERE branch = $1 AND (course_id = $2 OR course_id IS NULL) 
         AND semester = ANY($3)
         ORDER BY id ASC"
    )
    .bind(branch).bind(course_id).bind(&variations).fetch_all(pool).await
    .map(|rows| rows.into_iter().map(|r| (r.get("id"), r.get("name"))).collect())
}

pub async fn find_subjects_by_year_fallback(pool: &PgPool, branch: &str, course_id: Option<&str>, year: &str) -> Result<Vec<(String, String)>, sqlx::Error> {
    sqlx::query(
        "SELECT id, name FROM subjects 
         WHERE branch = $1 AND (course_id = $2 OR course_id IS NULL) 
         AND (semester LIKE $3 OR semester LIKE $4 OR semester LIKE $5)
         ORDER BY id ASC"
    )
    .bind(branch).bind(course_id)
    .bind(format!("{}%", year))
    .bind(if year == "1st Year" { "1st Semester%" } else if year == "2nd Year" { "3rd Semester%" } else { "5th Semester%" })
    .bind(if year == "1st Year" { "2nd Semester%" } else if year == "2nd Year" { "4th Semester%" } else { "6th Semester%" })
    .fetch_all(pool).await
    .map(|rows| rows.into_iter().map(|r| (r.get("id"), r.get("name"))).collect())
}

pub async fn get_subject_progress_stats(pool: &PgPool, subject_id: &str, section: &str) -> Result<(i64, i64, i64), sqlx::Error> {
    let row = sqlx::query(
        r#"
        SELECT 
            COUNT(lpi.id) as total_topics,
            COUNT(CASE WHEN lp.completed = TRUE THEN 1 END) as completed_topics,
            COUNT(CASE WHEN ls.schedule_date <= NOW() THEN 1 END) as scheduled_topics
        FROM lesson_plan_items lpi
        LEFT JOIN lesson_plan_progress lp ON lpi.id = lp.item_id AND lp.section = $2
        LEFT JOIN lesson_schedule ls ON lpi.id = ls.topic_id AND ls.section = $2
        WHERE lpi.subject_id = $1
        "#
    )
    .bind(subject_id).bind(section).fetch_one(pool).await?;
    
    Ok((row.get("total_topics"), row.get("completed_topics"), row.get("scheduled_topics")))
}

pub async fn find_faculty_assignment(pool: &PgPool, branch: &str, year: &str, section: &str, subject_name: &str) -> Result<Option<(String, String)>, sqlx::Error> {
    let row = sqlx::query(
        "SELECT u.login_id, u.full_name FROM timetable_entries t
         JOIN users u ON t.faculty_id = u.login_id
         WHERE t.branch = $1 AND t.year = $2 AND t.section = $3 AND (t.subject = $4 OR t.subject_code = $4)
         LIMIT 1"
    )
    .bind(branch)
    .bind(year)
    .bind(section)
    .bind(subject_name)
    .fetch_optional(pool)
    .await?;

    Ok(row.map(|r| (r.get("login_id"), r.get("full_name"))))
}
