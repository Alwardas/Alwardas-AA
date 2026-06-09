use sqlx::{PgPool, Row};
use std::env;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();
    let db_url = env::var("DATABASE_URL")?;
    let pool = PgPool::connect(&db_url).await?;

    println!("--- ALL STAFF/HOD USERS ---");
    let rows = sqlx::query("SELECT id, login_id, full_name, role, branch, section FROM users WHERE role IN ('HOD', 'Incharge', 'Coordinator', 'Faculty')")
        .fetch_all(&pool)
        .await?;
    for r in rows {
        let id: uuid::Uuid = r.get("id");
        let login_id: String = r.get("login_id");
        let full_name: String = r.get("full_name");
        let role: String = r.get("role");
        let branch: Option<String> = r.get("branch");
        let section: Option<String> = r.get("section");
        println!("ID: {}, Login ID: {}, Name: {}, Role: {}, Branch: {:?}, Section: {:?}", id, login_id, full_name, role, branch, section);
    }

    println!("\n--- ALL FACULTY SUBJECTS IN DB ---");
    let rows = sqlx::query("SELECT user_id, subject_id, subject_name, branch, section, status FROM faculty_subjects")
        .fetch_all(&pool)
        .await?;
    for r in rows {
        let user_id: uuid::Uuid = r.get("user_id");
        let subject_id: String = r.get("subject_id");
        let subject_name: Option<String> = r.get("subject_name");
        let branch: Option<String> = r.get("branch");
        let section: Option<String> = r.get("section");
        let status: Option<String> = r.get("status");
        println!("User ID: {}, Subj: {}, Name: {:?}, Branch: {:?}, Sec: {:?}, Status: {:?}", user_id, subject_id, subject_name, branch, section, status);
    }

    println!("\n--- ALL CURRICULUM PROGRESS IN DB ---");
    let rows = sqlx::query("SELECT topic_id, subject_code, faculty_id, branch, section, year, status FROM curriculum_progress")
        .fetch_all(&pool)
        .await?;
    for r in rows {
        let topic_id: String = r.get("topic_id");
        let subject_code: String = r.get("subject_code");
        let faculty_id: uuid::Uuid = r.get("faculty_id");
        let branch: String = r.get("branch");
        let section: String = r.get("section");
        let year: String = r.get("year");
        let status: Option<String> = r.get("status");
        println!("Topic: {}, Subj: {}, Faculty: {}, Branch: {}, Sec: {}, Year: {}, Status: {:?}", topic_id, subject_code, faculty_id, branch, section, year, status);
    }

    println!("\n--- ALL COURSE SUBJECTS IN DB ---");
    let rows = sqlx::query("SELECT id, branch, year, section, subject_name, subject_code, created_by, course_id FROM course_subjects")
        .fetch_all(&pool)
        .await?;
    for r in rows {
        let id: uuid::Uuid = r.get("id");
        let branch: String = r.get("branch");
        let year: String = r.get("year");
        let section: String = r.get("section");
        let subject_name: String = r.get("subject_name");
        let subject_code: Option<String> = r.get("subject_code");
        let created_by: String = r.get("created_by");
        let course_id: String = r.get("course_id");
        println!("ID: {}, Branch: {}, Year: {}, Sec: {}, SubjName: {}, SubjCode: {:?}, CreatedBy: {}, CourseID: {}", id, branch, year, section, subject_name, subject_code, created_by, course_id);
    }

    println!("\n--- ALL TIMETABLE ENTRIES FOR PYTHON OR 505 ---");
    let rows = sqlx::query("SELECT faculty_id, branch, year, section, subject, subject_code FROM timetable_entries WHERE subject ILIKE '%python%' OR subject_code ILIKE '%505%'")
        .fetch_all(&pool)
        .await?;
    for r in rows {
        let faculty_id: String = r.get("faculty_id");
        let branch: String = r.get("branch");
        let year: String = r.get("year");
        let section: String = r.get("section");
        let subject: String = r.get("subject");
        let subject_code: Option<String> = r.get("subject_code");
        println!("Faculty ID: {}, Branch: {}, Year: {}, Sec: {}, Subject: {}, Code: {:?}", faculty_id, branch, year, section, subject, subject_code);
    }

    Ok(())
}

