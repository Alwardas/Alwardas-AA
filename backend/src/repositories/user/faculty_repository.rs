use sqlx::{PgPool, Postgres, Row, QueryBuilder};
use uuid::Uuid;
use crate::models::{
    FacultyProfileResponse, FacultySubjectResponse, StudentBasicInfo, 
    FacultyListDTO, StudentsQuery, FacultyByBranchQuery, AttendanceStatsResponse,
    StudentAttendanceItem
};

pub async fn find_profile_by_id(pool: &PgPool, user_uuid: Uuid) -> Result<Option<FacultyProfileResponse>, sqlx::Error> {
    sqlx::query_as::<Postgres, FacultyProfileResponse>(
        "SELECT full_name, login_id, role, branch, phone_number, dob, experience, email, title FROM users WHERE id = $1"
    )
    .bind(user_uuid)
    .fetch_optional(pool)
    .await
}

pub async fn find_subjects_by_user_id(pool: &PgPool, user_uuid: Uuid) -> Result<Vec<FacultySubjectResponse>, sqlx::Error> {
    sqlx::query_as::<Postgres, FacultySubjectResponse>(
        "SELECT id, subject_id, subject_name, branch, section, status, created_at FROM faculty_subjects WHERE user_id = $1"
    )
    .bind(user_uuid)
    .fetch_all(pool)
    .await
}

pub async fn insert_faculty_subject(pool: &PgPool, user_uuid: Uuid, subject_id: &str, subject_name: &str, branch: &str, section: Option<&str>) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO faculty_subjects (user_id, subject_id, subject_name, branch, section, status) VALUES ($1, $2, $3, $4, $5, 'PENDING')")
        .bind(user_uuid).bind(subject_id).bind(subject_name).bind(branch).bind(section)
        .execute(pool).await.map(|r| r.rows_affected())
}

pub async fn delete_faculty_subject(pool: &PgPool, user_uuid: Uuid, subject_id: &str, section: Option<&str>) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM faculty_subjects WHERE user_id = $1 AND subject_id = $2 AND (section = $3 OR ($3 IS NULL AND section IS NULL))")
        .bind(user_uuid).bind(subject_id).bind(section)
        .execute(pool).await.map(|r| r.rows_affected())
}

pub async fn update_lesson_plan_complete(pool: &PgPool, item_id: &str, section: &str, completed: bool) -> Result<u64, sqlx::Error> {
    sqlx::query(
        "INSERT INTO lesson_plan_progress (item_id, section, completed, completed_date) 
         VALUES ($1, $2, $3, NOW()) 
         ON CONFLICT (item_id, section) 
         DO UPDATE SET completed = $3, completed_date = CASE WHEN $3 THEN NOW() ELSE NULL END"
    )
    .bind(item_id).bind(section).bind(completed)
    .execute(pool).await.map(|r| r.rows_affected())
}

pub async fn update_feedback_reply(pool: &PgPool, feedback_id: Uuid, reply: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("UPDATE lesson_plan_feedback SET reply = $1, replied_at = NOW() WHERE id = $2")
        .bind(reply).bind(feedback_id)
        .execute(pool).await.map(|r| r.rows_affected())
}

pub async fn find_feedbacks_by_faculty_id(pool: &PgPool, faculty_id: &str) -> Result<Vec<crate::models::FacultyFeedbackResponse>, sqlx::Error> {
    sqlx::query_as::<Postgres, crate::models::FacultyFeedbackResponse>(
        r#"
        SELECT 
            lpf.id, lpf.user_id, lpf.rating, lpf.issue_type, lpf.comment, lpf.created_at, lpf.reply, lpf.replied_at,
            u.full_name as student_name, lpi.topic as lesson_topic
        FROM lesson_plan_feedback lpf
        JOIN lesson_plan_items lpi ON lpf.lesson_plan_item_id = lpi.id
        JOIN subjects s ON lpi.subject_id = s.id::text
        JOIN users u ON lpf.user_id = u.id
        WHERE (s.faculty_name = $1 OR s.id::text IN (SELECT subject_id FROM faculty_subjects WHERE user_id IN (SELECT id FROM users WHERE login_id = $1)))
        ORDER BY lpf.created_at DESC
        "#
    )
    .bind(faculty_id).fetch_all(pool).await
}

pub async fn find_students(pool: &PgPool, params: StudentsQuery) -> Result<Vec<StudentBasicInfo>, sqlx::Error> {
    let mut query = QueryBuilder::new("SELECT id, login_id as student_id, full_name, branch, year, semester, section FROM users WHERE role = 'Student'");
    
    if let Some(b) = &params.branch { 
        let variations = crate::models::get_branch_variations(b);
        query.push(" AND branch = ANY("); 
        query.push_bind(variations); 
        query.push(")");
    }
    if let Some(y) = &params.year { query.push(" AND year = "); query.push_bind(y); }
    if let Some(s) = &params.semester { query.push(" AND semester = "); query.push_bind(s); }
    if let Some(sec) = &params.section { query.push(" AND section = "); query.push_bind(sec); }
    
    query.push(" ORDER BY login_id ASC");
    query.build_query_as::<StudentBasicInfo>().fetch_all(pool).await
}

pub async fn find_faculty_by_branch(pool: &PgPool, params: FacultyByBranchQuery) -> Result<Vec<FacultyListDTO>, sqlx::Error> {
    sqlx::query_as::<Postgres, FacultyListDTO>(
        "SELECT login_id as faculty_id, full_name, branch, email, phone_number FROM users WHERE role = 'Faculty' AND (branch = $1 OR $1 IS NULL) ORDER BY full_name ASC"
    )
    .bind(params.branch).fetch_all(pool).await
}

pub async fn update_students_section(pool: &PgPool, student_ids: &[String], new_section: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("UPDATE users SET section = $1 WHERE login_id = ANY($2) AND role = 'Student'")
        .bind(new_section).bind(student_ids)
        .execute(pool).await.map(|r| r.rows_affected())
}

pub async fn insert_attendance(executor: &mut sqlx::Transaction<'_, Postgres>, student_uuid: Uuid, date: &str, status: &str, session: &str, section: &str) -> Result<u64, sqlx::Error> {
    sqlx::query(
        "INSERT INTO attendance (student_uuid, date, status, session, section) 
         VALUES ($1, $2::DATE, $3, $4, $5) 
         ON CONFLICT (student_uuid, date, session) DO UPDATE SET status = $3"
    )
    .bind(student_uuid).bind(date).bind(status).bind(session).bind(section)
    .execute(&mut **executor).await.map(|r| r.rows_affected())
}

pub async fn find_attendance_status(pool: &PgPool, branch: &str, year: &str, section: &str, date: &str, session: Option<&str>) -> Result<serde_json::Value, sqlx::Error> {
    let variations = crate::models::get_branch_variations(branch);
    
    let total_students: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE role = 'Student' AND branch = ANY($1) AND year = $2 AND section = $3")
        .bind(&variations).bind(year).bind(section).fetch_one(pool).await?;

    let mut query = QueryBuilder::new("SELECT COUNT(*) FROM attendance WHERE date = ");
    query.push_bind(date);
    query.push(" AND (status = 'present' OR status = 'P' OR status = 'PRESENT') AND student_uuid IN (SELECT id FROM users WHERE branch = ANY(");
    query.push_bind(&variations);
    query.push(") AND year = ");
    query.push_bind(year);
    query.push(" AND section = ");
    query.push_bind(section);
    query.push(")");
    
    if let Some(s) = session {
        query.push(" AND session = ");
        query.push_bind(s);
    }
    
    let total_present: i64 = query.build_query_scalar().fetch_one(pool).await?;
    let total_absent = total_students - total_present;

    Ok(serde_json::json!({
        "totalStudents": total_students,
        "totalPresent": total_present,
        "totalAbsent": total_absent
    }))
}

pub async fn find_absent_students(pool: &PgPool, branch: &str, year: &str, section: &str, date: &str, session: Option<&str>) -> Result<Vec<StudentAttendanceItem>, sqlx::Error> {
    let variations = crate::models::get_branch_variations(branch);
    
    let mut query = QueryBuilder::new(r#"
        SELECT id, login_id as student_id, full_name 
        FROM users 
        WHERE role = 'Student' AND branch = ANY("#);
    query.push_bind(&variations);
    query.push(") AND year = ");
    query.push_bind(year);
    query.push(" AND section = ");
    query.push_bind(section);
    query.push(" AND id NOT IN (
        SELECT student_uuid FROM attendance WHERE date = ");
    query.push_bind(date);
    query.push(" AND (status = 'present' OR status = 'P' OR status = 'PRESENT')");
    
    if let Some(s) = session {
        query.push(" AND session = ");
        query.push_bind(s);
    }
    query.push(")");
    
    let rows = query.build().fetch_all(pool).await?;
    Ok(rows.into_iter().map(|r| StudentAttendanceItem {
        id: r.get::<Uuid, _>("id"),
        student_id: r.get::<String, _>("student_id"),
        full_name: r.get::<String, _>("full_name"),
        status: "absent".to_string()
    }).collect())
}

pub async fn approve_user_status(pool: &PgPool, user_id: Uuid, status: bool) -> Result<u64, sqlx::Error> {
    sqlx::query("UPDATE users SET is_approved = $1 WHERE id = $2").bind(status).bind(user_id).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn update_faculty_subject_status(pool: &PgPool, user_uuid: Uuid, subject_id: &str, action: &str) -> Result<u64, sqlx::Error> {
    let status = if action == "APPROVE" { "APPROVED" } else { "REJECTED" };
    sqlx::query("UPDATE faculty_subjects SET status = $1 WHERE user_id = $2 AND subject_id = $3")
        .bind(status).bind(user_uuid).bind(subject_id).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn find_notification_by_id(pool: &PgPool, id: Uuid) -> Result<Option<serde_json::Value>, sqlx::Error> {
    let row = sqlx::query("SELECT id, type, message, sender_id, branch, status, created_at FROM notifications WHERE id = $1")
        .bind(id).fetch_optional(pool).await?;
    
    Ok(row.map(|r| serde_json::json!({
        "id": r.get::<Uuid, _>("id"),
        "type": r.get::<String, _>("type"),
        "message": r.get::<String, _>("message"),
        "sender_id": r.get::<String, _>("sender_id"),
        "branch": r.get::<Option<String>, _>("branch"),
        "status": r.get::<String, _>("status"),
        "created_at": r.get::<chrono::DateTime<chrono::Utc>, _>("created_at")
    })))
}

pub async fn delete_notification(pool: &PgPool, id: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM notifications WHERE id = $1").bind(id).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn find_profile_update_request(pool: &PgPool, user_id: Uuid) -> Result<Option<serde_json::Value>, sqlx::Error> {
    sqlx::query_scalar("SELECT new_data FROM profile_update_requests WHERE user_id = $1 AND status = 'PENDING'")
        .bind(user_id).fetch_optional(pool).await
}

pub async fn update_user_profile(executor: &mut sqlx::Transaction<'_, Postgres>, user_id: Uuid, data: &crate::models::ProfileUpdateRequestData) -> Result<u64, sqlx::Error> {
    sqlx::query(
        "UPDATE users SET full_name = COALESCE($1, full_name), phone_number = COALESCE($2, phone_number), email = COALESCE($3, email), experience = COALESCE($4, experience), dob = COALESCE($5::DATE, dob) WHERE id = $6"
    )
    .bind(&data.full_name).bind(&data.phone_number).bind(&data.email).bind(&data.experience).bind(&data.dob).bind(user_id)
    .execute(&mut **executor).await.map(|r| r.rows_affected())
}

pub async fn update_profile_request_status(executor: &mut sqlx::Transaction<'_, Postgres>, user_id: Uuid, status: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("UPDATE profile_update_requests SET status = $1 WHERE user_id = $2 AND status = 'PENDING'")
        .bind(status).bind(user_id).execute(&mut **executor).await.map(|r| r.rows_affected())
}

pub async fn find_correction_request(pool: &PgPool, id: Uuid) -> Result<Option<serde_json::Value>, sqlx::Error> {
    let row = sqlx::query("SELECT user_id, dates FROM attendance_correction_requests WHERE id = $1").bind(id).fetch_optional(pool).await?;
    Ok(row.map(|r| serde_json::json!({
        "user_id": r.get::<Uuid, _>("user_id"),
        "dates": r.get::<serde_json::Value, _>("dates")
    })))
}

pub async fn update_correction_request_status(executor: &mut sqlx::Transaction<'_, Postgres>, id: Uuid, status: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("UPDATE attendance_correction_requests SET status = $1 WHERE id = $2").bind(status).bind(id).execute(&mut **executor).await.map(|r| r.rows_affected())
}

pub async fn insert_user(pool: &PgPool, payload: &crate::models::CreateStudentRequest) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO users (full_name, login_id, role, branch, year, semester, section, password_hash, is_approved) VALUES ($1, $2, 'Student', $3, $4, $5, $6, $7, TRUE)")
        .bind(&payload.full_name).bind(&payload.student_id).bind(&payload.branch).bind(&payload.year).bind(&payload.semester).bind(&payload.section).bind(&payload.student_id)
        .execute(pool).await.map(|r| r.rows_affected())
}

pub async fn find_sections(pool: &PgPool, branch: &str, year: &str) -> Result<Vec<String>, sqlx::Error> {
    sqlx::query_scalar("SELECT section_name FROM sections WHERE branch = $1 AND year = $2").bind(branch).bind(year).fetch_all(pool).await
}

pub async fn insert_section(pool: &PgPool, branch: &str, year: &str, section: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO sections (branch, year, section_name) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING").bind(branch).bind(year).bind(section).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn delete_sections_by_branch_year(pool: &PgPool, branch: &str, year: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM sections WHERE branch = $1 AND year = $2").bind(branch).bind(year).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn delete_user(pool: &PgPool, user_id: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM users WHERE id = $1").bind(user_id).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn update_section_name(pool: &PgPool, branch: &str, year: &str, old_name: &str, new_name: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("UPDATE sections SET section_name = $1 WHERE branch = $2 AND year = $3 AND section_name = $4").bind(new_name).bind(branch).bind(year).bind(old_name).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn update_users_section_name(pool: &PgPool, branch: &str, year: &str, old_name: &str, new_name: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("UPDATE users SET section = $1 WHERE branch = $2 AND year = $3 AND section = $4 AND role = 'Student'").bind(new_name).bind(branch).bind(year).bind(old_name).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn insert_timetable_entry(pool: &PgPool, payload: &crate::models::AssignClassRequest) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO timetable_entries (faculty_id, branch, year, section, day, period_index, subject) VALUES ($1, $2, $3, $4, $5, $6, $7)")
        .bind(&payload.faculty_id).bind(&payload.branch).bind(&payload.year).bind(&payload.section).bind(&payload.day).bind(payload.period_index).bind(&payload.subject)
        .execute(pool).await.map(|r| r.rows_affected())
}

pub async fn find_timetable(pool: &PgPool, params: &std::collections::HashMap<String, String>) -> Result<Vec<crate::models::TimetableEntry>, sqlx::Error> {
    let mut query = QueryBuilder::new("SELECT t.id, t.faculty_id, t.branch, t.year, t.section, t.day, t.period_index, t.subject, t.subject_code, u.full_name as faculty_name, u.email as faculty_email, u.phone_number as faculty_phone, u.branch as faculty_department FROM timetable_entries t LEFT JOIN users u ON t.faculty_id = u.login_id WHERE 1=1");
    if let Some(f) = params.get("facultyId") { query.push(" AND t.faculty_id = "); query.push_bind(f); }
    if let Some(b) = params.get("branch") { query.push(" AND t.branch = "); query.push_bind(b); }
    if let Some(y) = params.get("year") { query.push(" AND t.year = "); query.push_bind(y); }
    if let Some(s) = params.get("section") { query.push(" AND t.section = "); query.push_bind(s); }
    query.push(" ORDER BY t.day, t.period_index");
    query.build_query_as::<crate::models::TimetableEntry>().fetch_all(pool).await
}

pub async fn delete_timetable_entry(pool: &PgPool, payload: &crate::models::AssignClassRequest) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM timetable_entries WHERE branch = $1 AND year = $2 AND section = $3 AND day = $4 AND period_index = $5")
        .bind(&payload.branch).bind(&payload.year).bind(&payload.section).bind(&payload.day).bind(payload.period_index)
        .execute(pool).await.map(|r| r.rows_affected())
}

pub async fn find_department_timings(pool: &PgPool, branch: Option<&str>) -> Result<Vec<crate::models::DepartmentTiming>, sqlx::Error> {
    let mut query = QueryBuilder::new("SELECT id, branch, start_time, end_time, total_periods, period_duration, lunch_after, lunch_duration FROM department_timings");
    if let Some(b) = branch { query.push(" WHERE branch = "); query.push_bind(b); }
    query.build_query_as::<crate::models::DepartmentTiming>().fetch_all(pool).await
}

pub async fn insert_department_timing(pool: &PgPool, branch: &str, start_time: &str, end_time: &str, total_periods: i32, period_duration: i32, lunch_after: i32, lunch_duration: i32) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO department_timings (branch, start_time, end_time, total_periods, period_duration, lunch_after, lunch_duration) VALUES ($1, $2, $3, $4, $5, $6, $7) ON CONFLICT (branch) DO UPDATE SET start_time = $2, end_time = $3, total_periods = $4, period_duration = $5, lunch_after = $6, lunch_duration = $7")
        .bind(branch).bind(start_time).bind(end_time).bind(total_periods).bind(period_duration).bind(lunch_after).bind(lunch_duration)
        .execute(pool).await.map(|r| r.rows_affected())
}

pub async fn find_courses(pool: &PgPool) -> Result<Vec<crate::models::CourseResponse>, sqlx::Error> {
    sqlx::query_as::<Postgres, crate::models::CourseResponse>("SELECT id, name FROM courses ORDER BY name ASC").fetch_all(pool).await
}

pub async fn find_semester_subjects(pool: &PgPool, params: crate::models::SemesterSubjectsQuery) -> Result<Vec<crate::models::SemesterSubjectResponse>, sqlx::Error> {
    sqlx::query_as::<Postgres, crate::models::SemesterSubjectResponse>("SELECT id, name, type as subject_type, credit FROM subjects WHERE branch = $1 AND semester = $2 ORDER BY id ASC")
        .bind(params.branch).bind(params.semester).fetch_all(pool).await
}

pub async fn find_lesson_topics(pool: &PgPool, params: crate::models::LessonTopicsQuery) -> Result<Vec<crate::models::LessonTopicResponse>, sqlx::Error> {
    sqlx::query_as::<Postgres, crate::models::LessonTopicResponse>("SELECT id, topic, text as description, sno FROM lesson_plan_items WHERE subject_id = $1 ORDER BY order_index ASC")
        .bind(params.subject_id).fetch_all(pool).await
}

pub async fn insert_lesson_schedule(executor: &mut sqlx::Transaction<'_, Postgres>, topic_id: &str, schedule_date: &str, branch: &str, year: &str, section: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO lesson_schedule (topic_id, schedule_date, branch, year, section) VALUES ($1, $2::DATE, $3, $4, $5) ON CONFLICT (topic_id, section) DO UPDATE SET schedule_date = $2::DATE")
        .bind(topic_id).bind(schedule_date).bind(branch).bind(year).bind(section)
        .execute(&mut **executor).await.map(|r| r.rows_affected())
}
