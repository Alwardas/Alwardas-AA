use sqlx::{PgPool};
use axum::http::StatusCode;
use uuid::Uuid;
use chrono::{Utc};
use crate::models::{
    StudentProfileResponse, ProfileUpdateRequestData, StudentCourse, LessonPlanResponse,
    LessonPlanFeedbackRequest, LessonPlanFeedbackResponse,
    StudentFeedbacksResponse, AttendanceSummary, AttendanceCorrectionRequestData,
    CorrectionRequestHistoryItem, SemesterAcademicsResponse, SubjectMarkResponse,
    normalize_branch
};
use crate::utils::user_utils::resolve_user_id;
use crate::repositories::user::student_repository;
use crate::services::curriculum_service;

fn get_expected_progress() -> i32 {
    use chrono::Datelike;
    match Utc::now().month() {
        1 | 8 => 15,
        2 | 9 => 35,
        3 | 10 => 60,
        4 | 11 => 85,
        5 | 12 => 100,
        _ => 50,
    }
}

pub async fn get_student_profile(pool: &PgPool, user_id: &str) -> Result<StudentProfileResponse, StatusCode> {
    let user_uuid = resolve_user_id(user_id, "Student", pool).await.map_err(|_| StatusCode::BAD_REQUEST)?;

    student_repository::find_profile_by_id(pool, user_uuid)
        .await
        .map_err(|e| {
            eprintln!("Profile Fetch Error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?
        .ok_or(StatusCode::NOT_FOUND)
}

pub async fn request_profile_update(pool: &PgPool, payload: ProfileUpdateRequestData) -> Result<(), (StatusCode, String)> {
    let user_uuid = Uuid::parse_str(&payload.user_id).map_err(|_| (StatusCode::BAD_REQUEST, "Invalid User ID".to_string()))?;
    let branch_str = payload.new_branch.clone().or(payload.branch.clone()).unwrap_or_default();
    let json_data = serde_json::to_value(&payload).map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Failed to serialize data".to_string()))?;

    let mut tx = pool.begin().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Failed to start transaction".to_string()))?;

    student_repository::delete_pending_update_requests(&mut tx, user_uuid).await.ok();
    student_repository::insert_profile_update_request(&mut tx, user_uuid, json_data).await
        .map_err(|e| {
            eprintln!("Request Update Error: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to create request".to_string())
        })?;

    let branch_for_notif = if branch_str.is_empty() {
        student_repository::get_user_branch(&mut tx, user_uuid).await.unwrap_or_default().unwrap_or_default()
    } else {
        branch_str
    };

    let (role_label, distinct_id, name) = if let Some(sid) = &payload.new_student_id {
        ("Student", sid.clone(), payload.new_full_name.clone().unwrap_or_default())
    } else if let Some(fid) = &payload.faculty_id {
        ("Faculty", fid.clone(), payload.full_name.clone().unwrap_or_default())
    } else {
        ("User", payload.user_id.clone(), "Unknown".to_string())
    };

    let msg = format!("{} {} ({}) requested profile update.", role_label, name, distinct_id);

    student_repository::insert_notification(&mut tx, "PROFILE_UPDATE_REQUEST", &msg, &payload.user_id, &branch_for_notif).await
        .map_err(|e| {
            eprintln!("Notif Error: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to create notification".to_string())
        })?;

    tx.commit().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Failed to commit transaction".to_string()))?;
    Ok(())
}

pub async fn get_student_courses(pool: &PgPool, user_id: &str) -> Result<Vec<StudentCourse>, StatusCode> {
    let user_uuid = resolve_user_id(user_id, "Student", pool).await.map_err(|_| StatusCode::BAD_REQUEST)?;

    let (branch, year, sem, section, _login_id) = student_repository::get_student_basics(pool, user_uuid)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    let branch_norm = normalize_branch(&branch.unwrap_or_default());
    let year_str = year.unwrap_or_default();
    let sem_str = sem.unwrap_or_default();
    let section_str = section.unwrap_or_else(|| "Section A".to_string());

    let semester_key = if year_str == "1st Year" {
        "1st Year".to_string()
    } else if !sem_str.is_empty() {
        sem_str
    } else {
        if year_str.contains("2nd Year") || year_str.contains("3rd Semester") { "3rd Semester".to_string() }
        else if year_str.contains("4th Semester") { "4th Semester".to_string() }
        else if year_str.contains("3rd Year") || year_str.contains("5th Semester") { "5th Semester".to_string() }
        else if year_str.contains("6th Semester") { "6th Semester".to_string() }
        else { "1st Year".to_string() }
    };

    let mut subjects = student_repository::find_subjects_by_branch_and_semester(pool, &branch_norm, &semester_key, &section_str)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Fallback: If DB returns empty, try to fetch from Assets
    if subjects.is_empty() {
        let sem_int = match semester_key.to_lowercase().as_str() {
            s if s.contains('1') => 1,
            s if s.contains('2') => 2,
            s if s.contains('3') => 3,
            s if s.contains('4') => 4,
            s if s.contains('5') => 5,
            s if s.contains('6') => 6,
            _ => 1
        };
        
        if let Ok(asset_subjects) = curriculum_service::get_subjects_from_assets(&branch_norm, sem_int, "C23").await {
            for (code, name, stype) in asset_subjects {
                subjects.push((code, name, stype, None, None, None, None));
            }
        }
    }

    let mut courses = Vec::new();
    let expected_progress = get_expected_progress();

    for (sid, sname, stype, rfn, fe, fp, fd) in subjects {
        let total_items = student_repository::count_lesson_plan_items(pool, &sid).await.unwrap_or(0);
        let completed_items = student_repository::count_completed_lesson_plan_items(pool, &sid, &section_str).await.unwrap_or(0);

        let progress = if total_items > 0 { (completed_items * 100) / total_items } else { 0 } as i32;
        let status = if progress < expected_progress - 10 { "Lagging".to_string() } else if progress > expected_progress + 10 { "Overfast".to_string() } else { "On Track".to_string() };

        courses.push(StudentCourse {
            id: sid,
            name: sname,
            faculty_name: rfn.unwrap_or("TBA".to_string()),
            credits: 3,
            progress,
            subject_type: stype,
            faculty_email: fe,
            faculty_phone: fp,
            faculty_department: fd,
            status: Some(status),
        });
    }

    Ok(courses)
}

pub async fn get_student_lesson_plan(pool: &PgPool, subject_id: &str, section_param: Option<String>, branch_param: Option<String>, user_id_param: Option<String>) -> Result<LessonPlanResponse, (StatusCode, String)> {
    let subject_id = subject_id.trim();

    let section = if let Some(s) = section_param {
         s
    } else if let Some(uid_str) = user_id_param.clone() {
         let user_uuid = Uuid::parse_str(&uid_str).unwrap_or_default();
         let (_, _, _, sec, _) = student_repository::get_student_basics(pool, user_uuid).await.unwrap_or(None).unwrap_or_default();
         sec.unwrap_or_else(|| "Section A".to_string())
    } else {
         "Section A".to_string()
    };

    let branch_norm = if let Some(b) = branch_param {
        Some(normalize_branch(&b))
    } else if let Some(uid_str) = user_id_param {
         let user_uuid = Uuid::parse_str(&uid_str).unwrap_or_default();
         let (br, _, _, _, _) = student_repository::get_student_basics(pool, user_uuid).await.unwrap_or(None).unwrap_or_default();
         br.map(|b| normalize_branch(&b))
    } else {
         None
    };

    let items = student_repository::get_lesson_plan_items(pool, subject_id, &section, branch_norm.as_deref())
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let total = items.len();
    let completed = items.iter().filter(|i| i.completed.unwrap_or(false)).count();
    let percentage = if total > 0 { (completed * 100) / total } else { 0 } as i32;
    let expected = get_expected_progress();
    let status = if percentage < expected - 10 { "LAGGING".to_string() } else if percentage > expected + 10 { "OVERFAST".to_string() } else { "NORMAL".to_string() };

    Ok(LessonPlanResponse {
        percentage,
        status,
        warning: if percentage < expected - 10 { Some("You are lagging behind schedule.".to_string()) } else { None },
        items,
    })
}

pub async fn submit_lesson_plan_feedback(pool: &PgPool, payload: LessonPlanFeedbackRequest) -> Result<(), StatusCode> {
    student_repository::insert_lesson_plan_feedback(pool, &payload.lesson_plan_id, payload.user_id, payload.rating, &payload.issue_type, &payload.comment)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(())
}

pub async fn delete_lesson_plan_feedback(pool: &PgPool, feedback_id: Uuid, user_id: Uuid) -> Result<(), (StatusCode, String)> {
    let row = student_repository::get_feedback_owner_and_date(pool, feedback_id)
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "DB Error".to_string()))?;

    if let Some((owner_id, created_at)) = row {
         if owner_id != user_id { return Err((StatusCode::FORBIDDEN, "Not authorized".to_string())); }
         if Utc::now().signed_duration_since(created_at).num_hours() > 24 { return Err((StatusCode::BAD_REQUEST, "Cannot delete after 24 hours".to_string())); }
         student_repository::delete_lesson_plan_feedback(pool, feedback_id).await
            .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Failed to delete".to_string()))?;
         Ok(())
    } else {
         Err((StatusCode::NOT_FOUND, "Feedback not found".to_string()))
    }
}

pub async fn get_lesson_plan_feedback(pool: &PgPool, lesson_plan_id: &str) -> Result<Vec<LessonPlanFeedbackResponse>, StatusCode> {
    student_repository::get_lesson_plan_feedback(pool, lesson_plan_id)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_student_all_feedbacks(pool: &PgPool, user_id: &str) -> Result<Vec<StudentFeedbacksResponse>, (StatusCode, String)> {
    let user_uuid = resolve_user_id(user_id, "Student", pool).await.map_err(|(c, j)| (c, j.0["error"].as_str().unwrap_or("Unknown").to_string()))?;
    student_repository::get_student_all_feedbacks(pool, user_uuid)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))
}

pub async fn get_student_attendance(pool: &PgPool, student_id: &str) -> Result<AttendanceSummary, StatusCode> {
    let student_uuid = resolve_user_id(student_id, "Student", pool).await.map_err(|_| StatusCode::NOT_FOUND)?;

    let history = student_repository::get_attendance_history(pool, student_uuid)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let (mut present, mut absent) = (0, 0);
    for r in &history { if r.status == "P" || r.status == "PRESENT" { present += 1; } else if r.status == "A" || r.status == "ABSENT" { absent += 1; } }
    let total = present + absent;
    let percentage = if total > 0 { (present as f64 / total as f64) * 100.0 } else { 0.0 };

    Ok(AttendanceSummary { total_classes: total, present_count: present, absent_count: absent, percentage, history })
}

pub async fn request_attendance_correction(pool: &PgPool, payload: AttendanceCorrectionRequestData) -> Result<Uuid, (StatusCode, String)> {
    let user_uuid = if let Ok(uuid) = Uuid::parse_str(&payload.user_id) { uuid } else {
        return Err((StatusCode::BAD_REQUEST, "Invalid User ID".to_string()));
    };

    let profile = student_repository::find_profile_by_id(pool, user_uuid)
        .await
        .map_err(|_| (StatusCode::NOT_FOUND, "User not found".to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "User not found".to_string()))?;

    let dates_json = serde_json::to_value(&payload.items).unwrap();

    let mut tx = pool.begin().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Failed to start transaction".to_string()))?;

    let request_id = student_repository::insert_attendance_correction_request(&mut tx, user_uuid, dates_json, &payload.reason)
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "DB Error".to_string()))?;

    let msg = format!("{} attendance correction request", profile.full_name);
    student_repository::insert_notification(&mut tx, "ATTENDANCE_CORRECTION_REQUEST", &msg, &payload.user_id, &profile.branch.unwrap_or_else(|| "General".to_string())).await.ok();

    tx.commit().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Failed to commit transaction".to_string()))?;

    Ok(request_id)
}

pub async fn get_attendance_correction_requests(pool: &PgPool, student_id: &str) -> Result<Vec<CorrectionRequestHistoryItem>, (StatusCode, String)> {
    let student_uuid = resolve_user_id(student_id, "Student", pool).await.map_err(|(c, j)| (c, j["error"].as_str().unwrap_or("Unknown").to_string()))?;
    student_repository::get_attendance_correction_requests(pool, student_uuid)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))
}

pub async fn delete_attendance_correction_requests(pool: &PgPool, ids: Vec<Uuid>) -> Result<(), StatusCode> {
    student_repository::delete_attendance_correction_requests(pool, ids)
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn get_student_academics(pool: &PgPool, user_id: &str) -> Result<Vec<SemesterAcademicsResponse>, (StatusCode, String)> {
    let user_uuid = resolve_user_id(user_id, "Student", pool).await.map_err(|(c, j)| (c, j.0["error"].as_str().unwrap_or("Unknown").to_string()))?;

    let (branch, year, sem, _, login_id) = student_repository::get_student_basics(pool, user_uuid)
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "DB Error".to_string()))?
        .ok_or((StatusCode::NOT_FOUND, "User not found".to_string()))?;

    let branch_norm = normalize_branch(&branch.unwrap_or_default());
    let year_str = year.unwrap_or_default();
    let sem_str = sem.unwrap_or_default();
    let semester_key = if year_str == "1st Year" { "1st Year".to_string() } else if !sem_str.is_empty() { sem_str } else {
        if year_str.contains("2nd Year") { "3rd Semester".to_string() } else if year_str.contains("3rd Year") { "5th Semester".to_string() } else { "1st Year".to_string() }
    };

    let sems = vec![("1st Year", "1st Year", "Semester 1"), ("2nd Year", "3rd Semester", "Semester 3"), ("2nd Year", "4th Semester", "Semester 4"), ("3rd Year", "5th Semester", "Semester 5"), ("3rd Year", "6th Semester", "Semester 6")];
    let mut result = Vec::new();
    for (yl, db_sem, disp_sem) in sems {
        let subjects = student_repository::get_subjects_by_semester(pool, &branch_norm, db_sem).await.unwrap_or_default();
        let mut sub_res = Vec::new();
        let (mut pts, mut crds) = (0.0, 0.0);
        let mut all_present = !subjects.is_empty();
        for (sid, sname, scrd) in subjects {
            let cval = scrd.unwrap_or(3);
            let mark = student_repository::get_student_mark(pool, &login_id, db_sem, &sname).await.unwrap_or(None).flatten();
            let (grade, gp) = if let Some(m) = mark {
                let g = if m >= 90 { ("O", 10) } else if m >= 80 { ("A+", 9) } else if m >= 70 { ("A", 8) } else if m >= 60 { ("B+", 7) } else if m >= 50 { ("B", 6) } else if m >= 40 { ("C", 5) } else { ("F", 0) };
                (Some(g.0.to_string()), Some(g.1))
            } else { all_present = false; (None, None) };
            if let Some(p) = gp { pts += (p * cval) as f64; crds += cval as f64; }
            sub_res.push(SubjectMarkResponse { subject_id: sid, subject_name: sname, marks: mark, credit: cval, grade, grade_points: gp });
        }
        result.push(SemesterAcademicsResponse { year_label: yl.to_string(), semester_name: disp_sem.to_string(), is_ongoing: db_sem == semester_key, subjects: sub_res, sgpa: if all_present && crds > 0.0 { Some(pts / crds) } else { None } });
        if db_sem == semester_key { break; }
    }
    Ok(result)
}
