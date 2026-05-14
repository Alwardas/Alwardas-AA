use std::path::Path;
use tokio::fs;
use crate::models::curriculum::{CurriculumJson, CurriculumProgressRow};
use crate::repositories::curriculum_repository;
use sqlx::PgPool;
use serde_json;

pub async fn get_merged_curriculum(
    pool: &PgPool,
    branch: &str,
    semester: i32,
    regulation: &str,
    subject_code: &str,
    section: &str,
    year: &str,
) -> Result<CurriculumJson, Box<dyn std::error::Error>> {
    // 1. Resolve JSON Path
    // Path structure: ../frontend/assets/curriculum/{regulation}/{branch}/{semester}/{type}/{subject}.json
    // We need to find the file. We can search in theory and practical folders.
    
    let branch_short = _map_to_short_branch(branch);
    let semester_dir = format!("semester {}", semester);
    
    let base_path = format!(
        "../frontend/assets/curriculum/{}/{}/{}",
        regulation.to_lowercase(),
        branch_short.to_lowercase(),
        semester_dir
    );

    let mut json_content = None;
    
    // Check theory
    let theory_path = format!("{}/theory/{}.json", base_path, subject_code);
    if Path::new(&theory_path).exists() {
        json_content = Some(fs::read_to_string(theory_path).await?);
    } else {
        // Check practical
        let practical_path = format!("{}/practical/{}.json", base_path, subject_code);
        if Path::new(&practical_path).exists() {
            json_content = Some(fs::read_to_string(practical_path).await?);
        }
    }

    let json_str = json_content.ok_or_else(|| format!("Curriculum JSON not found for {}", subject_code))?;
    let mut curriculum: CurriculumJson = serde_json::from_str(&json_str)?;

    // 2. Fetch Progress from DB
    let progress_rows = curriculum_repository::get_progress(pool, subject_code, branch, section, year).await?;
    let feedback_stats = curriculum_repository::get_topic_feedback_stats(pool, subject_code).await?;

    // 3. Merge
    for unit in &mut curriculum.units {
        for topic in &mut unit.topics {
            // Find progress
            if let Some(row) = progress_rows.iter().find(|r| r.topic_id == topic.id) {
                topic.status = row.status.clone();
                topic.assigned_date = row.assigned_date;
                topic.completed_date = row.completed_date;
                topic.remarks = row.remarks.clone();
            } else {
                topic.status = Some("pending".to_string());
            }

            // Find feedback
            if let Some(feedback) = feedback_stats.iter().find(|(tid, _, _)| tid == &topic.id) {
                topic.feedback_count = Some(feedback.1);
                topic.understood_percentage = Some(feedback.2);
            } else {
                topic.feedback_count = Some(0);
                topic.understood_percentage = Some(0.0);
            }
        }
    }

    Ok(curriculum)
}

pub async fn get_subjects_from_assets(
    branch: &str,
    semester: i32,
    regulation: &str,
) -> Result<Vec<(String, String, String)>, Box<dyn std::error::Error>> {
    let branch_short = _map_to_short_branch(branch);
    let semester_dir = format!("semester {}", semester);
    
    let base_path = format!(
        "../frontend/assets/curriculum/{}/{}/{}",
        regulation.to_lowercase(),
        branch_short.to_lowercase(),
        semester_dir
    );

    let mut subjects = Vec::new();

    // Read theory
    let theory_path = format!("{}/theory", base_path);
    if let Ok(mut entries) = fs::read_dir(&theory_path).await {
        while let Ok(Some(entry)) = entries.next_entry().await {
            if let Some(name) = entry.file_name().to_str() {
                if name.ends_with(".json") {
                    let code = name.replace(".json", "");
                    let content = fs::read_to_string(entry.path()).await?;
                    let data: serde_json::Value = serde_json::from_str(&content)?;
                    let sub_name = data["subjectName"].as_str().unwrap_or(&code).to_string();
                    subjects.push((code, sub_name, "Theory".to_string()));
                }
            }
        }
    }

    // Read practical
    let practical_path = format!("{}/practical", base_path);
    if let Ok(mut entries) = fs::read_dir(&practical_path).await {
        while let Ok(Some(entry)) = entries.next_entry().await {
            if let Some(name) = entry.file_name().to_str() {
                if name.ends_with(".json") {
                    let code = name.replace(".json", "");
                    let content = fs::read_to_string(entry.path()).await?;
                    let data: serde_json::Value = serde_json::from_str(&content)?;
                    let sub_name = data["subjectName"].as_str().unwrap_or(&code).to_string();
                    subjects.push((code, sub_name, "Practical".to_string()));
                }
            }
        }
    }

    Ok(subjects)
}

fn _map_to_short_branch(branch: &str) -> &str {
    match branch {
        "Computer Engineering" => "cme",
        "Electronics & Communication Engineering" => "ece",
        "Electrical and Electronics Engineering" => "eee",
        "Mechanical Engineering" => "mech",
        "Civil Engineering" => "civ",
        _ => "cme",
    }
}
