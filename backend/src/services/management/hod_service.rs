use sqlx::{PgPool};
use axum::http::StatusCode;
use std::collections::HashMap;
use crate::models::{
    MasterTimetableQuery, MasterTimetableResponse, MasterTimetableRow, FacultyClash, 
    TimetableEntry, normalize_branch, BranchProgressResponse, YearProgressResponse,
    SectionProgressResponse, SubjectProgressResponse, AddCourseSubjectRequest, 
    SectionQuery, SubjectQuery, BranchProgressQuery, YearSectionsProgressQuery, 
    SectionSubjectsProgressQuery, FacultyAssignmentQuery
};
use crate::repositories::management::hod_repository;

pub async fn get_hod_departments(pool: &PgPool) -> Result<Vec<String>, StatusCode> {
    hod_repository::find_hod_departments(pool)
        .await
        .map_err(|e| {
            eprintln!("Failed to fetch department branches: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })
}

pub async fn get_hod_sections(pool: &PgPool, params: SectionQuery) -> Result<Vec<String>, StatusCode> {
    hod_repository::find_sections_by_branch_and_year(pool, &params.branch, &params.year)
        .await
        .map_err(|e| {
            eprintln!("Failed to fetch sections: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })
}

pub async fn get_hod_subjects(pool: &PgPool, params: SubjectQuery) -> Result<Vec<String>, StatusCode> {
    hod_repository::find_subjects_by_branch_and_year(pool, &params.branch, &params.year)
        .await
        .map_err(|e| {
            eprintln!("Failed to fetch subjects: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })
}

pub async fn add_course_subject(pool: &PgPool, payload: AddCourseSubjectRequest) -> Result<(), (StatusCode, String)> {
    let existing = hod_repository::find_existing_course_subject(pool, &payload.branch, &payload.year, &payload.section, &payload.subject_name)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    if existing.is_some() {
        return Err((StatusCode::CONFLICT, "Subject already assigned.".to_string()));
    }

    let course_id = payload.course_id.clone().unwrap_or_else(|| "C-23".to_string());
    hod_repository::insert_course_subject(pool, &payload.branch, &payload.year, &payload.section, &payload.subject_name, payload.subject_code.as_deref(), &payload.created_by, &course_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(())
}

pub async fn get_added_course_subjects(pool: &PgPool, user_id: &str) -> Result<Vec<serde_json::Value>, StatusCode> {
    hod_repository::find_added_course_subjects(pool, user_id)
        .await
        .map_err(|e| {
            eprintln!("Failed to fetch added course subjects: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })
}

pub async fn get_all_staff(pool: &PgPool) -> Result<Vec<serde_json::Value>, StatusCode> {
    hod_repository::find_all_staff(pool)
        .await
        .map_err(|e| {
            eprintln!("Failed to fetch staff list: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })
}

pub async fn get_master_timetable(pool: &PgPool, params: MasterTimetableQuery) -> Result<MasterTimetableResponse, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    let day = &params.day;

    let class_combos = hod_repository::find_class_combos(pool, &branch_norm).await.unwrap_or_default();

    if class_combos.is_empty() {
        return Ok(MasterTimetableResponse { rows: vec![], lab_rows: vec![], faculty_clashes: vec![] });
    }

    let entries = hod_repository::find_timetable_entries_by_day(pool, &branch_norm, day)
        .await
        .map_err(|e| {
            eprintln!("Master Timetable Fetch Error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    let mut entries_map: HashMap<(String, String), HashMap<i32, TimetableEntry>> = HashMap::new();
    for entry in entries {
        entries_map
            .entry((entry.year.clone(), entry.section.clone()))
            .or_default()
            .insert(entry.period_index, entry);
    }

    let mut rows = Vec::new();
    for (year, section) in class_combos {
        let mut periods = Vec::new();
        for p in 0..8 {
            let entry = entries_map.get(&(year.clone(), section.clone())).and_then(|m| m.get(&(p + 1)).cloned());
            periods.push(entry);
        }

        rows.push(MasterTimetableRow {
            class_name: format!("{} - {}", year, section),
            year,
            section,
            periods,
        });
    }

    let lab_names = hod_repository::find_lab_names_by_branch(pool, &branch_norm).await.unwrap_or_default();

    let mut lab_rows = Vec::new();
    for lab_name in lab_names {
        let mut periods = Vec::new();
        for p in 0..8 {
            let entry = entries_map.get(&("Lab".to_string(), lab_name.clone())).and_then(|m| m.get(&(p + 1)).cloned());
            periods.push(entry);
        }

        lab_rows.push(MasterTimetableRow {
            class_name: lab_name.clone(),
            year: "Lab".to_string(),
            section: lab_name,
            periods,
        });
    }

    let mut faculty_occupancy: HashMap<(i32, String), Vec<String>> = HashMap::new();
    let mut faculty_names: HashMap<String, String> = HashMap::new();

    let all_display_rows = rows.iter().chain(lab_rows.iter());

    for row in all_display_rows {
        for (idx, period) in row.periods.iter().enumerate() {
            if let Some(entry) = period {
                let key = (idx as i32, entry.faculty_id.clone());
                faculty_occupancy.entry(key).or_default().push(row.class_name.clone());
                if let Some(name) = &entry.faculty_name {
                    faculty_names.insert(entry.faculty_id.clone(), name.clone());
                }
            }
        }
    }

    let mut faculty_clashes = Vec::new();
    for ((period_idx, faculty_id), classes) in faculty_occupancy {
        if classes.len() > 1 {
            faculty_clashes.push(FacultyClash {
                faculty_name: faculty_names.get(&faculty_id).cloned().unwrap_or(faculty_id),
                day: day.clone(),
                period_index: period_idx + 1,
                classes,
            });
        }
    }

    Ok(MasterTimetableResponse {
        rows,
        lab_rows,
        faculty_clashes,
    })
}

pub async fn get_faculty_assignment(pool: &PgPool, params: FacultyAssignmentQuery) -> Result<serde_json::Value, StatusCode> {
    let res = hod_repository::find_faculty_assignment(pool, &params.branch, &params.year, &params.section, params.subject_name.as_deref().unwrap_or(""))
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if let Some((id, name)) = res {
        Ok(serde_json::json!({ "facultyId": id, "facultyName": name }))
    } else {
        Ok(serde_json::json!({ "facultyId": null, "facultyName": "Not Assigned" }))
    }
}

pub async fn get_branch_progress(pool: &PgPool, params: BranchProgressQuery) -> Result<BranchProgressResponse, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    let years = vec!["1st Year", "2nd Year", "3rd Year"];
    let mut year_responses = Vec::new();
    let mut total_avg = 0.0;

    for year in years {
        let progress = calculate_year_progress(pool, &branch_norm, &params.course_id, year).await.unwrap_or(0);
        year_responses.push(YearProgressResponse {
            year: year.to_string(),
            percentage: progress,
        });
        total_avg += progress as f64;
    }

    let overall = (total_avg / 3.0).round() as i32;

    Ok(BranchProgressResponse {
        branch: branch_norm,
        years: year_responses,
        overall_percentage: overall,
    })
}

pub async fn get_year_sections_progress(pool: &PgPool, params: YearSectionsProgressQuery) -> Result<Vec<SectionProgressResponse>, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    
    let sections = hod_repository::find_sections_with_student_fallback(pool, &branch_norm, &params.year).await.unwrap_or_default();

    let mut responses = Vec::new();
    for section in sections {
        let progress = calculate_section_progress(pool, &branch_norm, &params.course_id, &params.year, &section).await.unwrap_or(0);
        responses.push(SectionProgressResponse {
            section_name: section,
            percentage: progress,
        });
    }

    Ok(responses)
}

pub async fn get_section_subjects_progress(pool: &PgPool, params: SectionSubjectsProgressQuery) -> Result<Vec<SubjectProgressResponse>, StatusCode> {
    let branch_norm = normalize_branch(&params.branch);
    
    let semester_pattern = params.semester.as_ref().map(|s| {
        match s.as_str() {
            "Semester 1" => vec!["1st Year".to_string(), "1st Semester".to_string()],
            "Semester 3" => vec!["3rd Semester".to_string(), "3rd".to_string()],
            "Semester 4" => vec!["4th Semester".to_string()],
            "Semester 5" => vec!["5th Semester".to_string()],
            "Semester 6" => vec!["6th Semester".to_string()],
            _ => vec![s.clone()],
        }
    });

    let subjects = if let Some(patterns) = semester_pattern {
        hod_repository::find_subjects_by_semester_variations(pool, &branch_norm, Some(&params.course_id), patterns).await.unwrap_or_default()
    } else {
        hod_repository::find_subjects_by_year_fallback(pool, &branch_norm, Some(&params.course_id), &params.year).await.unwrap_or_default()
    };

    let mut responses = Vec::new();
    for (sid, sname) in subjects {
        let (progress, status) = calculate_subject_progress(pool, &sid, &params.section).await;
        responses.push(SubjectProgressResponse {
            subject_id: sid,
            subject_name: sname,
            percentage: progress,
            status,
        });
    }

    Ok(responses)
}

// --- Internal Calculation Helpers ---

pub async fn calculate_year_progress(pool: &PgPool, branch: &str, course_id: &str, year: &str) -> Option<i32> {
    let sections = hod_repository::find_sections_with_student_fallback(pool, branch, year).await.unwrap_or_default();

    if sections.is_empty() { return Some(0); }

    use futures::future::join_all;
    let mut futures = Vec::new();
    for section in &sections {
        futures.push(calculate_section_progress(pool, branch, course_id, year, section));
    }

    let results = join_all(futures).await;
    let mut total = 0.0;
    for res in results {
        total += res.unwrap_or(0) as f64;
    }

    Some((total / sections.len() as f64).round() as i32)
}

pub async fn calculate_section_progress(pool: &PgPool, branch: &str, course_id: &str, year: &str, section: &str) -> Option<i32> {
    let subjects = hod_repository::find_subjects_by_year_fallback(pool, branch, Some(course_id), year).await.unwrap_or_default();

    if subjects.is_empty() { return Some(0); }

    use futures::future::join_all;
    let mut futures = Vec::new();
    for (sid, _) in &subjects {
        futures.push(calculate_subject_progress(pool, sid, section));
    }

    let results = join_all(futures).await;
    let mut total = 0.0;
    for (progress, _) in results {
        total += progress as f64;
    }

    Some((total / subjects.len() as f64).round() as i32)
}

pub async fn calculate_subject_progress(pool: &PgPool, subject_id: &str, section: &str) -> (i32, String) {
    let stats = hod_repository::get_subject_progress_stats(pool, subject_id, section).await.ok();

    if let Some((total, completed, scheduled)) = stats {
        let percentage = if total > 0 { (completed as f64 * 100.0 / total as f64).round() as i32 } else { 0 };
        
        let status = if completed < scheduled {
            "Lagging".to_string()
        } else if completed > scheduled {
            "Overfast".to_string()
        } else {
            "On Track".to_string()
        };

        (percentage, status)
    } else {
        (0, "On Track".to_string())
    }
}
