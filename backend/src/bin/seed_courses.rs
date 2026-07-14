use sqlx::postgres::PgPoolOptions;
use dotenvy::dotenv;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct CurriculumJson {
    #[serde(rename = "subjectCode")]
    subject_code: String,
    #[serde(rename = "subjectName")]
    subject_name: String,
    regulation: String,
    semester: i32,
    units: Vec<UnitJson>,
}

#[derive(Debug, Deserialize)]
struct UnitJson {
    #[serde(rename = "unitNo")]
    unit_no: i32,
    title: String,
    topics: Vec<TopicJson>,
}

#[derive(Debug, Deserialize)]
struct TopicJson {
    id: String,
    sno: Option<String>,
    topic: String,
    #[serde(rename = "type")]
    topic_type: Option<String>,
}

fn traverse_dir(dir: &Path, files: &mut Vec<PathBuf>) -> Result<(), std::io::Error> {
    if dir.is_dir() {
        for entry in fs::read_dir(dir)? {
            let entry = entry?;
            let path = entry.path();
            if path.is_dir() {
                traverse_dir(&path, files)?;
            } else if path.extension().and_then(|s| s.to_str()) == Some("json") {
                files.push(path);
            }
        }
    }
    Ok(())
}

fn map_branch(branch_code: &str) -> &str {
    match branch_code.to_lowercase().as_str() {
        "cme" => "Computer Engineering",
        "civ" => "Civil Engineering",
        "ece" => "Electronics & Communication Engineering",
        "eee" => "Electrical & Electronics Engineering",
        "mech" => "Mechanical Engineering",
        _ => "Computer Engineering",
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");

    let pool = PgPoolOptions::new()
        .max_connections(1)
        .connect(&database_url)
        .await?;

    println!("Connected to database.");

    // Path to newly created curriculum folders
    let cur_dir = Path::new("../frontend/assets/curriculum");
    if !cur_dir.exists() {
        eprintln!("Curriculum directory not found: {:?}", cur_dir);
        return Ok(());
    }

    let mut json_files = Vec::new();
    traverse_dir(cur_dir, &mut json_files)?;

    println!("Found {} curriculum JSON files to seed.", json_files.len());

    for path in json_files {
        println!("Processing file: {:?}", path);
        let content = fs::read_to_string(&path)?;
        
        let curriculum: CurriculumJson = match serde_json::from_str(&content) {
            Ok(c) => c,
            Err(e) => {
                eprintln!("Failed to parse {:?}: {}", path, e);
                continue;
            }
        };

        // Extract branch and type from path components
        // Path matches format: .../curriculum/{regulation}/{branch}/{semester}/{type}/{subject}.json
        // Or for C26: .../curriculum/{regulation}/{branch}/{semester}/{subject}.json
        let components: Vec<String> = path
            .components()
            .map(|c| c.as_os_str().to_string_lossy().into_owned())
            .collect();
        
        let curriculum_index = components
            .iter()
            .position(|c| c.to_lowercase() == "curriculum")
            .unwrap_or(0);
        
        let mut branch_code = "cme";
        let mut type_code = "theory";
        
        if curriculum_index + 2 < components.len() {
            branch_code = &components[curriculum_index + 2];
        }
        if curriculum_index + 4 < components.len() {
            let next_comp = &components[curriculum_index + 4];
            if !next_comp.to_lowercase().ends_with(".json") {
                type_code = next_comp;
            }
        }

        let branch_name = map_branch(branch_code);
        let subject_type = type_code.to_uppercase();
        let semester_name = format!("Semester {}", curriculum.semester);

        // Format course_id to match C-23 or C-26 database strings
        let reg = curriculum.regulation.trim().replace("-", "");
        let course_id_str = if reg.len() >= 2 {
            format!("{}-{}", &reg[..1], &reg[1..])
        } else {
            reg
        };

        println!(
            "Seeding subject: {} ({}) | Branch: {} | Type: {} | Sem: {} | Regulation: {}",
            curriculum.subject_code, curriculum.subject_name, branch_name, subject_type, semester_name, course_id_str
        );

        // 1. Seed Subject
        sqlx::query(
            "INSERT INTO subjects (id, name, semester, type, branch, faculty_name, course_id) 
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             ON CONFLICT (id) DO UPDATE 
             SET name = $2, semester = $3, type = $4, branch = $5, course_id = $7"
        )
        .bind(&curriculum.subject_code)
        .bind(&curriculum.subject_name)
        .bind(&semester_name)
        .bind(&subject_type)
        .bind(branch_name)
        .bind(None::<String>)
        .bind(&course_id_str)
        .execute(&pool)
        .await?;

        // 2. Clear existing lesson plan items for this subject to prevent duplicates/conflicts
        sqlx::query("DELETE FROM lesson_plan_items WHERE subject_id = $1")
            .bind(&curriculum.subject_code)
            .execute(&pool)
            .await?;

        // 3. Seed new lesson plan items
        let mut order_counter = 0;
        for unit in &curriculum.units {
            // Seed unit header row
            order_counter += 1;
            let unit_id = format!("{}-UNIT-{}", curriculum.subject_code.to_uppercase(), unit.unit_no);
            let unit_title = format!("Unit {}: {}", unit.unit_no, unit.title);

            sqlx::query(
                "INSERT INTO lesson_plan_items (id, subject_id, type, text, topic, sno, order_index, completed, completed_date, target_date, review, student_review)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
                 ON CONFLICT (id) DO UPDATE 
                 SET subject_id = EXCLUDED.subject_id,
                     type = EXCLUDED.type,
                     text = EXCLUDED.text,
                     topic = EXCLUDED.topic,
                     sno = EXCLUDED.sno,
                     order_index = EXCLUDED.order_index"
            )
            .bind(&unit_id)
            .bind(&curriculum.subject_code)
            .bind("unit")
            .bind(&unit_title)
            .bind(&unit_title)
            .bind(None::<String>)
            .bind(order_counter)
            .bind(false)
            .bind(None::<chrono::DateTime<chrono::Utc>>)
            .bind(None::<chrono::DateTime<chrono::Utc>>)
            .bind(None::<String>)
            .bind(None::<String>)
            .execute(&pool)
            .await?;

            for topic in &unit.topics {
                order_counter += 1;
                let topic_type = topic.topic_type.clone().unwrap_or_else(|| "theory".to_string()).to_uppercase();
                let topic_sno = topic.sno.clone().unwrap_or_else(|| format!("{}.{}", unit.unit_no, order_counter));
                let db_topic_id = format!("{}-{}-{}", curriculum.subject_code.to_uppercase(), topic.id, order_counter);

                sqlx::query(
                    "INSERT INTO lesson_plan_items (id, subject_id, type, text, topic, sno, order_index, completed, completed_date, target_date, review, student_review)
                     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
                     ON CONFLICT (id) DO UPDATE 
                     SET subject_id = EXCLUDED.subject_id,
                         type = EXCLUDED.type,
                         text = EXCLUDED.text,
                         topic = EXCLUDED.topic,
                         sno = EXCLUDED.sno,
                         order_index = EXCLUDED.order_index"
                )
                .bind(&db_topic_id)
                .bind(&curriculum.subject_code)
                .bind(&topic_type)
                .bind(None::<String>)
                .bind(&topic.topic)
                .bind(&topic_sno)
                .bind(order_counter)
                .bind(false)
                .bind(None::<chrono::DateTime<chrono::Utc>>)
                .bind(None::<chrono::DateTime<chrono::Utc>>)
                .bind(None::<String>)
                .bind(None::<String>)
                .execute(&pool)
                .await?;
            }
        }
        
        println!("Successfully seeded {} topics for {}", order_counter, curriculum.subject_code);
    }

    println!("All curriculum files successfully seeded!");
    Ok(())
}
