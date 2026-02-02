
use sqlx::postgres::PgPoolOptions;
use dotenvy::dotenv;
use std::env;
use std::fs;
use std::path::Path;
use serde::Deserialize;
use std::collections::HashMap;
use chrono::TimeZone;

#[derive(Debug, Deserialize)]
struct CourseData {
    branch_name: String,
    semesters: Option<HashMap<String, CategoryData>>,
    lesson_plans: Option<HashMap<String, Vec<LessonPlanItemJson>>>,
}

#[derive(Debug, Deserialize)]
struct CategoryData {
    theory: Option<Vec<SubjectJson>>,
    practical: Option<Vec<SubjectJson>>,
}

#[derive(Debug, Deserialize)]
struct SubjectJson {
    id: String,
    name: String,
    faculty: Option<String>,
}

#[derive(Debug, Deserialize)]
struct LessonPlanItemJson {
    id: Option<String>,
    #[serde(rename = "type")]
    item_type: String,
    text: Option<String>,
    topic: Option<String>,
    sno: Option<String>,
    completed: Option<bool>,
    #[serde(rename = "completedDate")]
    completed_date: Option<String>,
    #[serde(rename = "targetDate")]
    target_date: Option<String>,
    review: Option<String>,
    #[serde(rename = "studentReview")]
    student_review: Option<String>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await?;

    println!("Connected to database.");

    // Path to JSON data
    // The script is running from backend/, so path is ../frontend/data/json
    let data_dir = Path::new("../frontend/data/json");
    if !data_dir.exists() {
        eprintln!("Data directory not found: {:?}", data_dir);
        return Ok(());
    }

    let entries = fs::read_dir(data_dir)?;

    for entry in entries {
        let entry = entry?;
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) == Some("json") {
            println!("Processing {:?}", path.file_name().unwrap());
            let content = fs::read_to_string(&path)?;
            
            // Allow loose parsing (ignore unknown fields)
            let data: CourseData = match serde_json::from_str(&content) {
                Ok(d) => d,
                Err(e) => {
                    eprintln!("Failed to parse {:?}: {}", path, e);
                    continue;
                }
            };

            seed_branch(&pool, data).await?;
        }
    }

    Ok(())
}

async fn seed_branch(pool: &sqlx::Pool<sqlx::Postgres>, data: CourseData) -> Result<(), Box<dyn std::error::Error>> {
    let branch = data.branch_name;

    // 1. Seed Subjects
    if let Some(semesters) = data.semesters {
        for (sem_name, categories) in semesters {
            if let Some(theory) = categories.theory {
                for subj in theory {
                    upsert_subject(pool, subj, &sem_name, "THEORY", &branch).await?;
                }
            }
            if let Some(practical) = categories.practical {
                for subj in practical {
                    upsert_subject(pool, subj, &sem_name, "PRACTICAL", &branch).await?;
                }
            }
        }
    }

    // 2. Seed Lesson Plans
    if let Some(plans) = data.lesson_plans {
        for (subject_id, items) in plans {
            seed_lesson_plan(pool, &subject_id, items).await?;
        }
    }

    Ok(())
}

async fn upsert_subject(
    pool: &sqlx::Pool<sqlx::Postgres>, 
    subj: SubjectJson, 
    semester: &str, 
    rtype: &str, 
    branch: &str
) -> Result<(), Box<dyn std::error::Error>> {
    sqlx::query(
        "INSERT INTO subjects (id, name, semester, type, branch, faculty_name) 
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (id) DO UPDATE 
         SET name = $2, semester = $3, type = $4, branch = $5, faculty_name = $6"
    )
    .bind(&subj.id)
    .bind(&subj.name)
    .bind(semester)
    .bind(rtype)
    .bind(branch)
    .bind(&subj.faculty)
    .execute(pool)
    .await?;
    
    Ok(())
}

async fn seed_lesson_plan(
    pool: &sqlx::Pool<sqlx::Postgres>,
    subject_id: &str,
    items: Vec<LessonPlanItemJson>
) -> Result<(), Box<dyn std::error::Error>> {
    // Check subject exists first (Foreign Key constraint)
    let exists: Option<(String,)> = sqlx::query_as("SELECT id FROM subjects WHERE id = $1")
        .bind(subject_id)
        .fetch_optional(pool)
        .await?;
    
    if exists.is_none() {
        println!("Skipping lesson plan for unknown subject: {}", subject_id);
        return Ok(());
    }

    // Clear existing items for this subject
    sqlx::query("DELETE FROM lesson_plan_items WHERE subject_id = $1")
        .bind(subject_id)
        .execute(pool)
        .await?;

    let mut order_counter = 0;
    for item in items {
        order_counter += 1;
        let item_id = item.id.clone().unwrap_or_else(|| format!("{}-auto-{}", subject_id, order_counter));

        let target_date = item.target_date.as_deref().and_then(parse_date_string);
        let completed_date = item.completed_date.as_deref().and_then(parse_date_string);

        sqlx::query(
            "INSERT INTO lesson_plan_items (id, subject_id, type, text, topic, sno, order_index, completed, completed_date, target_date, review, student_review)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)"
        )
        .bind(item_id)
        .bind(subject_id)
        .bind(item.item_type.to_uppercase())
        .bind(item.text)
        .bind(item.topic)
        .bind(item.sno)
        .bind(order_counter)
        .bind(item.completed.unwrap_or(false))
        .bind(completed_date)
        .bind(target_date)
        .bind(item.review)
        .bind(item.student_review)
        .execute(pool)
        .await
        .map_err(|e| println!("Error inserting item: {}", e))
        .ok();
    }
    
    Ok(())
}

fn parse_date_string(date_str: &str) -> Option<chrono::DateTime<chrono::Utc>> {
    // Try standard ISO 8601
    if let Ok(dt) = chrono::DateTime::parse_from_rfc3339(date_str) {
        return Some(dt.with_timezone(&chrono::Utc));
    }
    
    // Try YYYY-MM-DD
    if let Ok(d) = chrono::NaiveDate::parse_from_str(date_str, "%Y-%m-%d") {
        return chrono::Utc.from_local_datetime(&d.and_hms_opt(0,0,0)?).single();
    }

    None
}
