use axum::{
    routing::{get, post},
    Router,
};
use sqlx::{postgres::{PgPoolOptions, PgConnectOptions}, Pool, Postgres};
use tower_http::cors::CorsLayer;
use dotenvy::dotenv;
use std::str::FromStr;

pub mod auth_proto {
    tonic::include_proto!("auth");
}

mod services;
use services::auth::MyAuthService;
use auth_proto::auth_service_server::AuthServiceServer;

mod models;
use models::AppState;

mod routes;
use routes::*;

use tower::Service;
use axum::body::Body;

#[tokio::main]
async fn main() {
    let port = std::env::var("PORT")
        .unwrap_or_else(|_| "3001".to_string())
        .parse::<u16>()
        .expect("Invalid PORT");
    
    let addr = std::net::SocketAddr::from(([0, 0, 0, 0], port));
    println!("🚀 Server listening on {}", addr);
    println!("v1.5 - Sections Fix");
    
    // Bind early to ensure Railway sees the port open
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();

    dotenv().ok();
    let raw_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    
    // Robust parsing: strip "DATABASE_URL=" prefix if it exists (common copy-paste error)
    let trimmed_url = if raw_url.trim().starts_with("DATABASE_URL=") {
        raw_url.trim().strip_prefix("DATABASE_URL=").unwrap().trim()
    } else {
        raw_url.trim()
    };

    // Redact password for logging
    let redacted_url = if let Some(at_pos) = trimmed_url.find('@') {
        if let Some(pass_start) = trimmed_url[..at_pos].find(':') {
             // Second colon usually starts password in postgres://user:pass@host
             if let Some(pass_at) = trimmed_url[(pass_start + 1)..at_pos].find(':') {
                let actual_pass_start = pass_start + 1 + pass_at;
                format!("{}***{}", &trimmed_url[..actual_pass_start+1], &trimmed_url[at_pos..])
             } else {
                trimmed_url.to_string()
             }
        } else {
            trimmed_url.to_string()
        }
    } else {
        trimmed_url.to_string()
    };
    println!("🔌 Using Connection String: {}", redacted_url);

    let options = PgConnectOptions::from_str(trimmed_url)
        .expect("Failed to parse DATABASE_URL")
        .statement_cache_capacity(0);

    println!("⏳ Connecting to database (Attempting with 60s timeout and retries)...");
    
    let mut retry_count = 0;
    let max_retries = 5;
    let pool = loop {
        match PgPoolOptions::new()
            .max_connections(10)
            .acquire_timeout(std::time::Duration::from_secs(60)) 
            .connect_with(options.clone())
            .await 
        {
            Ok(p) => break p,
            Err(e) => {
                retry_count += 1;
                println!("❌ Database connection attempt {} failed. Error: {:?}", retry_count, e);
                if retry_count >= max_retries {
                    panic!("❌ CRITICAL: Failed to connect to the database after {} attempts.", max_retries);
                }
                println!("⏳ Retrying in 5 seconds...");
                tokio::time::sleep(std::time::Duration::from_secs(5)).await;
            }
        }
    };

    println!("✅ Successfully connected to the database!");

    // Run migrations
    // Run migrations
    match sqlx::migrate!("./migrations").run(&pool).await {
        Ok(_) => println!("✅ Migrations complete!"),
        Err(e) => {
            eprintln!("⚠️ Migration warning: {}. The app will try to continue.", e);
        }
    }
    
    // FORCE FIX SCHEMA
    println!("🔧 Attempting to force-fix schema...");
    let _ = sqlx::query("DELETE FROM announcements WHERE title ILIKE '%Fixed Schema Test%' OR title ILIKE '%Local Test%'")
        .execute(&pool).await.map_err(|e| eprintln!("Delete test announcements failed: {:?}", e));
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS announcements (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            title VARCHAR(255) NOT NULL,
            description TEXT NOT NULL,
            type VARCHAR(50) NOT NULL,
            audience TEXT[] NOT NULL,
            priority VARCHAR(50) NOT NULL,
            start_date TIMESTAMPTZ NOT NULL,
            end_date TIMESTAMPTZ NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
            attachment_url VARCHAR(255),
            creator_id UUID NOT NULL
        )
    ").execute(&pool).await.map_err(|e| eprintln!("Force Fix Announcements Failed: {:?}", e));

    let _ = sqlx::query("ALTER TABLE attendance ADD COLUMN IF NOT EXISTS section VARCHAR(50) DEFAULT 'Section A'")
        .execute(&pool)
        .await
        .map_err(|e| eprintln!("Force Fix Attendance Failed: {:?}", e));
        
    let _ = sqlx::query("ALTER TABLE users ADD COLUMN IF NOT EXISTS section VARCHAR(50) DEFAULT 'Section A'")
        .execute(&pool)
        .await
        .map_err(|e| eprintln!("Force Fix Users Failed: {:?}", e));
        
    let _ = sqlx::query("ALTER TABLE users ADD COLUMN IF NOT EXISTS title VARCHAR(100) DEFAULT NULL")
        .execute(&pool)
        .await
        .map_err(|e| eprintln!("Force Fix Users Title Failed: {:?}", e));
        
    // FORCE DATA REPAIR
    let _ = sqlx::query("UPDATE users SET section = 'Section A' WHERE section IS NULL")
        .execute(&pool)
        .await;
    let _ = sqlx::query("UPDATE users SET is_approved = true WHERE role = 'Student' AND is_approved = false")
        .execute(&pool)
        .await;

    // DISTRIBUTE FOR TESTING (Enable Section B) - COMMENTED OUT TO PREVENT AUTO-MOVE
    // let _ = sqlx::query("UPDATE users SET section = 'Section B' WHERE role = 'Student' AND section = 'Section A' AND right(login_id, 1) IN ('0', '2', '4', '6', '8')")
    //     .execute(&pool)
    //     .await;
    
    // ONE-TIME FIX removed to prevent resetting student sections
    // let _ = sqlx::query("UPDATE users SET section = 'Section A' WHERE role = 'Student'")...
        
    // FORCE FIX SCHEMA - FACULTY SUBJECTS
    let _ = sqlx::query("ALTER TABLE faculty_subjects ADD COLUMN IF NOT EXISTS section VARCHAR(50) DEFAULT 'Section A'")
        .execute(&pool).await.err();
        
    let _ = sqlx::query("ALTER TABLE faculty_subjects DROP CONSTRAINT IF EXISTS faculty_subjects_pkey")
        .execute(&pool).await.err();

    let _ = sqlx::query("ALTER TABLE faculty_subjects ADD PRIMARY KEY (user_id, subject_id, section)")
        .execute(&pool).await.err();

    // FORCE FIX SCHEMA - LESSON PLAN PROGRESS
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS lesson_plan_progress (
            item_id TEXT REFERENCES lesson_plan_items(id) ON DELETE CASCADE,
            section VARCHAR(50),
            completed BOOLEAN DEFAULT FALSE,
            completed_date TIMESTAMPTZ,
            PRIMARY KEY (item_id, section)
        )
    ").execute(&pool).await.err();

    // DEPARTMENT TIMINGS TABLE
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS department_timings (
            branch TEXT PRIMARY KEY,
            start_hour INT NOT NULL DEFAULT 9,
            start_minute INT NOT NULL DEFAULT 0,
            class_duration INT NOT NULL DEFAULT 50,
            short_break_duration INT NOT NULL DEFAULT 10,
            lunch_duration INT NOT NULL DEFAULT 50,
            slot_config JSONB DEFAULT NULL
        )
    ").execute(&pool).await.err();

    // Migration: Add slot_config if not exists
    let _ = sqlx::query("ALTER TABLE department_timings ADD COLUMN IF NOT EXISTS slot_config JSONB DEFAULT NULL")
         .execute(&pool).await.err();
         
    // Migration: Add short_code if not exists
    let _ = sqlx::query("ALTER TABLE department_timings ADD COLUMN IF NOT EXISTS short_code VARCHAR(50) DEFAULT NULL")
         .execute(&pool).await.err();

    // SECTIONS TABLE (New)
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS sections (
            branch VARCHAR(255) NOT NULL,
            year VARCHAR(50) NOT NULL,
            section_name VARCHAR(50) NOT NULL,
            PRIMARY KEY (branch, year, section_name)
        )
    ").execute(&pool).await.err();
    
    // PARENT STUDENT TABLE (New)
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS parent_student (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            parent_id TEXT NOT NULL,
            student_id TEXT NOT NULL,
            relationship TEXT,
            UNIQUE(parent_id, student_id)
        )
    ").execute(&pool).await.err();

    // PARENT REQUESTS TABLE (New)
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS parent_requests (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            parent_id UUID NOT NULL REFERENCES users(id),
            student_id UUID NOT NULL REFERENCES users(id),
            request_type VARCHAR(50) NOT NULL,
            subject VARCHAR(255) NOT NULL,
            description TEXT NOT NULL,
            date_duration VARCHAR(100) NOT NULL,
            status VARCHAR(50) NOT NULL DEFAULT 'Pending',
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW(),
            assigned_to UUID REFERENCES users(id)
        )
    ").execute(&pool).await.err();
    
    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_parent_requests_parent_id ON parent_requests(parent_id)").execute(&pool).await.err();
    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_parent_requests_student_id ON parent_requests(student_id)").execute(&pool).await.err();

    // STUDENT MARKS TABLE
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS student_marks (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            student_id TEXT NOT NULL,
            semester TEXT NOT NULL,
            subject_name TEXT NOT NULL,
            marks INT DEFAULT NULL,
            UNIQUE(student_id, semester, subject_name)
        )
    ").execute(&pool).await.err();

    // Migration: Add credit if not exists
    let _ = sqlx::query("ALTER TABLE subjects ADD COLUMN IF NOT EXISTS credit INT DEFAULT 3")
         .execute(&pool).await.err();

    // TIMETABLE ENTRIES TABLE
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS timetable_entries (
            id UUID PRIMARY KEY,
            faculty_id TEXT NOT NULL,
            branch TEXT NOT NULL,
            year TEXT NOT NULL,
            section TEXT NOT NULL,
            day TEXT NOT NULL,
            period_index INT NOT NULL,
            subject TEXT NOT NULL,
            subject_code TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            UNIQUE(branch, year, section, day, period_index) 
        )
    ").execute(&pool).await.err();
    
    // COURSES TABLE
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS courses (
            course_id TEXT PRIMARY KEY,
            course_name TEXT NOT NULL
        )
    ").execute(&pool).await.err();

    // LESSON TOPICS TABLE
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS lesson_topics (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            subject_id TEXT NOT NULL,
            unit TEXT NOT NULL,
            topic_name TEXT NOT NULL
        )
    ").execute(&pool).await.err();

    // LESSON SCHEDULE TABLE
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS lesson_schedule (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            subject_id TEXT NOT NULL,
            topic_id TEXT NOT NULL,
            schedule_date TIMESTAMPTZ,
            faculty_id TEXT,
            branch TEXT NOT NULL,
            year TEXT NOT NULL,
            semester TEXT NOT NULL,
            UNIQUE(subject_id, topic_id)
        )
    ").execute(&pool).await.err();
    
    let _ = sqlx::query("CREATE EXTENSION IF NOT EXISTS \"pgcrypto\"").execute(&pool).await;

    // Force migration from older schema versions if they exist
    let _ = sqlx::query("ALTER TABLE issues RENAME COLUMN user_id TO created_by").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues RENAME COLUMN subject TO title").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues RENAME COLUMN created_at TO created_date").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues RENAME COLUMN responded_by TO assigned_to").execute(&pool).await;

    sqlx::query("
    
        CREATE TABLE IF NOT EXISTS issues (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            title VARCHAR(255) NOT NULL,
            description TEXT NOT NULL,
            category VARCHAR(100) NOT NULL DEFAULT 'General',
            priority VARCHAR(50) NOT NULL DEFAULT 'Medium',
            status VARCHAR(50) NOT NULL DEFAULT 'Open',
            created_by UUID NOT NULL REFERENCES users(id),
            user_role VARCHAR(50) NOT NULL DEFAULT 'Student',
            assigned_to UUID REFERENCES users(id),
            created_date TIMESTAMPTZ DEFAULT NOW()
        )
    ").execute(&pool).await.err();

    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS created_by UUID").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS user_role VARCHAR(50) DEFAULT 'Student'").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS category VARCHAR(100) DEFAULT 'General'").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS priority VARCHAR(50) DEFAULT 'Medium'").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS created_date TIMESTAMPTZ DEFAULT NOW()").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS title VARCHAR(255)").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS description TEXT").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS assigned_to UUID").execute(&pool).await;

    sqlx::query("
        CREATE TABLE IF NOT EXISTS issue_comments (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            issue_id UUID NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
            comment TEXT NOT NULL,
            comment_by UUID NOT NULL REFERENCES users(id),
            comment_date TIMESTAMPTZ DEFAULT NOW()
        )
    ").execute(&pool).await.err();

    // Fallback: If `courses` table is empty, insert some default courses
    let mut tx = pool.begin().await.unwrap();
    let courses_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM courses").fetch_one(&mut *tx).await.unwrap_or(0);
    if courses_count == 0 {
        sqlx::query("INSERT INTO courses (course_id, course_name) VALUES ('C-23', 'Computer Engineering (C-23)'), ('C-26', 'Computer Engineering (C-26)')").execute(&mut *tx).await.unwrap();
    }
    tx.commit().await.unwrap();
    
    // Wait, let's also seed 'lesson_topics' if empty for existing subjects
    let mut tx2 = pool.begin().await.unwrap();
    let topics_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM lesson_topics").fetch_one(&mut *tx2).await.unwrap_or(0);
    if topics_count == 0 {
        // Insert a dummy topic for testing
        sqlx::query("INSERT INTO lesson_topics (subject_id, unit, topic_name) VALUES ('1', 'Unit 1', 'Basics of Java'), ('1', 'Unit 1', 'Variables & Data Types')").execute(&mut *tx2).await.unwrap_or_default();
    }
    tx2.commit().await.unwrap();


    // Allow multiple faculty to potentially teach if sections are different, but unique constraint above enforces
    // one class per section per period.
    // However, faculty view is 'my schedule'.
    // If faculty A assigns class for Branch X Year Y Section Z Period 1, no one else can assign for that same target.
    // The previous constraint UNIQUE(branch, year, section, day, period_index) ensures no double booking for the *class*.
    // But we also need to ensure no double booking for the *faculty*? 
    // Maybe let's stick to the class constraint first.


    // OPTIMIZATION INDEXES
    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_attendance_lookup ON attendance(branch, year, session, date, section)")
        .execute(&pool).await.err();
        
    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_users_lookup ON users(branch, year, section, role)")
        .execute(&pool).await.err();

    println!("🔧 Schema fix & Data distribution complete.");

    // Fix Branch Names (Run in background)
    let fix_pool = pool.clone();
    tokio::spawn(async move {
        fix_branch_names(&fix_pool).await;
    });

    // --- MULTIPLEXING SETUP ---
    let grpc_pool = pool.clone();
    let auth_service = MyAuthService { pool: grpc_pool };
    let grpc_service = tonic::transport::Server::builder()
        .add_service(AuthServiceServer::new(auth_service))
        .into_service();


    let app = Router::new()
        .route("/", get(root))
        .route("/health", get(health_check))
        .route("/api/signup", post(signup_handler))
        .route("/api/login", post(login_handler))
        .route("/api/auth/check", get(check_user_existence_handler))
        .route("/api/forgot-password", post(forgot_password_handler))
        .route("/api/auth/change-password", post(change_password_handler))
        .route("/api/user/update", post(update_user_handler))
        .route("/api/notifications", get(get_notifications_handler))
        .route("/api/notifications/delete", post(delete_notifications_handler))
        .route("/api/student/profile", get(student::get_student_profile_handler))
        .route("/api/student/courses", get(student::get_student_courses_handler))
        .route("/api/student/lesson-plan", get(student::get_student_lesson_plan_handler))
        .route("/api/student/academics", get(student::get_student_academics_handler))
        .route("/api/student/lesson-plan/feedback", post(student::submit_lesson_plan_feedback_handler).get(student::get_lesson_plan_feedback_handler))
        .route("/api/student/lesson-plan/feedback/:id", axum::routing::delete(student::delete_lesson_plan_feedback_handler))
        .route("/api/student/feedbacks", get(student::get_student_all_feedbacks_handler))
        .route("/api/issues/submit", post(issue::submit_issue_handler))
        .route("/api/issues", get(issue::get_issues_handler))
        .route("/api/issues/:id", get(issue::get_issue_details_handler))
        .route("/api/issues/:id/comments", get(issue::get_issue_comments_handler))
        .route("/api/issues/comments/submit", post(issue::submit_comment_handler))
        .route("/api/issues/:id/assign", post(issue::assign_issue_handler))
        .route("/api/issues/:id/status", post(issue::update_issue_status_handler))
        .route("/api/user/request-update", post(student::request_profile_update_handler))
        .route("/api/user/request-attendance-correction", post(student::request_attendance_correction_handler))
        .route("/api/user/attendance-correction-requests", get(student::get_attendance_correction_requests_handler))
        .route("/api/user/attendance-correction-requests/delete", post(student::delete_attendance_correction_requests_handler))
        .route("/api/attendance", get(student::get_student_attendance_handler))
        .route("/api/user/my-pending-update", get(check_my_pending_update_handler))
        .route("/api/user/accept-my-update", post(accept_my_pending_update_handler))
        .route("/api/user/reject-my-update", post(reject_my_pending_update_handler))
        .route("/api/parent/profile", get(parent::get_parent_profile_handler))
        .route("/api/parent/requests/submit", post(parent::submit_parent_request_handler))
        .route("/api/parent/requests", get(parent::get_parent_requests_handler))
        .route("/api/parent/requests/:id/status", post(parent::update_parent_request_status_handler))
        .route("/api/faculty/profile", get(faculty::get_faculty_profile_handler))
        .route("/api/faculty/subjects", get(faculty::get_faculty_subjects_handler))
        .route("/api/faculty/subjects", post(faculty::add_faculty_subject_handler))
        .route("/api/faculty/subjects", axum::routing::delete(faculty::remove_faculty_subject_handler))
        .route("/api/faculty/lesson-plan/complete", post(faculty::mark_lesson_plan_complete_handler))
        .route("/api/faculty/lesson-plan/feedback/reply", post(faculty::reply_to_feedback_handler))
        .route("/api/faculty/by-branch", get(faculty::get_faculty_by_branch_handler))
        .route("/api/faculty/feedbacks", get(faculty::get_faculty_feedbacks_handler))
        // Removed old faculty issue routes, replaced by central ones above
        .route("/api/students", get(faculty::get_students_handler))
        .route("/api/students/create", post(faculty::create_student_handler))
        .route("/api/students/bulk-create", post(faculty::bulk_create_students_handler))
        .route("/api/students/move", post(faculty::move_students_handler))
        .route("/api/students/delete", post(faculty::delete_student_handler))
        .route("/api/attendance/submit", post(faculty::submit_attendance_handler))
        .route("/api/attendance/batch", post(faculty::submit_attendance_batch_handler))
        .route("/api/attendance/check", get(faculty::check_attendance_status_handler))
        .route("/api/sections", get(faculty::get_sections_handler))
        .route("/api/sections/update", post(faculty::update_sections_handler))
        .route("/api/sections/rename", post(faculty::rename_section_handler))
        .route("/api/attendance/class-record", get(faculty::get_class_attendance_record_handler))
        .route("/api/attendance/stats", get(faculty::get_attendance_stats_handler))
        .route("/api/attendance/absents", get(faculty::get_absent_students_handler))
        .route("/api/hod/approve", post(faculty::approve_handler))
        .route("/api/hod/approve-subject", post(faculty::approve_subject_handler))
        .route("/api/hod/approve-profile-change", post(faculty::approve_profile_change_handler))
        .route("/api/hod/approve-attendance-correction", post(faculty::approve_attendance_correction_handler))
        .route("/api/timetable", get(faculty::get_timetable_handler))
        .route("/api/timetable/assign", post(faculty::assign_class_handler))
        .route("/api/timetable/clear", post(faculty::clear_class_handler))
        .route("/api/department/timing", get(faculty::get_department_timings))
        .route("/api/department/timing", post(faculty::update_department_timings))
        .route("/api/faculty/hod-courses", get(faculty::get_courses_handler))
        .route("/api/faculty/hod-semester-subjects", get(faculty::get_semester_subjects_handler))
        .route("/api/faculty/hod-lesson-topics", get(faculty::get_lesson_topics_handler))
        .route("/api/faculty/hod-assign-schedule", post(faculty::assign_lesson_schedule_handler))
        .route("/api/admin/users", get(admin::get_admin_users_handler))
        .route("/api/admin/stats", get(admin::get_admin_stats_handler))
        .route("/api/admin/users/approve", post(admin::admin_approve_user_handler))
        .route("/api/principal/approve-hod", post(principal::principal_approve_hod_handler))
        .route("/api/announcement", post(coordinator::create_announcement_handler).get(coordinator::get_announcements_handler))
        .route("/api/announcement/delete", post(coordinator::delete_announcement_handler))
        .route("/api/announcement/pin", post(coordinator::pin_announcement_handler))
        .route("/api/departments", get(coordinator::get_all_departments_handler))
        .route("/api/departments/delete", post(coordinator::delete_department_handler))
        .route("/api/hod/departments", get(hod::get_hod_departments_handler))
        .route("/api/hod/sections", get(hod::get_hod_sections_handler))
        .route("/api/hod/subjects", get(hod::get_hod_subjects_handler))
        .route("/api/hod/course-subjects", post(hod::add_course_subject_handler).get(hod::get_added_course_subjects_handler))
        .route("/api/hod/master-timetable", get(hod::get_master_timetable_handler))
        .route("/api/hod/syllabus/branch-progress", get(hod::get_branch_progress_handler))
        .route("/api/hod/syllabus/year-sections-progress", get(hod::get_year_sections_progress_handler))
        .route("/api/hod/syllabus/section-subjects-progress", get(hod::get_section_subjects_progress_handler))
        .with_state(AppState { pool })
        .fallback(move |req: axum::extract::Request| {
            let mut grpc_service = grpc_service.clone();
            async move {
                if req.headers().get("content-type").map_or(false, |v| v.as_bytes().starts_with(b"application/grpc")) {
                    use http_body_util::BodyExt;
                    let (parts, body) = req.into_parts();
                    let body = body.map_err(|e| tonic::Status::internal(e.to_string())).boxed_unsync();
                    let req = axum::http::Request::from_parts(parts, body);
                    
                    use axum::response::IntoResponse;
                    match grpc_service.call(req).await {
                        Ok(resp) => resp.into_response(),
                        Err(e) => {
                            eprintln!("DEBUG: gRPC Error: {:?}", e);
                            axum::http::Response::builder()
                                .status(axum::http::StatusCode::INTERNAL_SERVER_ERROR)
                                .body(Body::empty())
                                .unwrap()
                        }
                    }
                } else {
                    println!("DEBUG: 404 Not Found: {} {}", req.method(), req.uri());
                    axum::http::Response::builder()
                        .status(axum::http::StatusCode::NOT_FOUND)
                        .body(Body::from("Route Not Found"))
                        .unwrap()
                }
            }
        })
        .layer(CorsLayer::permissive());

    println!("✅ Server ready");
    axum::serve(listener, app).await.unwrap();
}

async fn root() -> &'static str {
    "Alwardas Backend Running!"
}

async fn health_check() -> &'static str {
    "OK"
}

async fn fix_branch_names(pool: &Pool<Postgres>) {
    let updates = vec![
        ("CME", "Computer Engineering"),
        ("CM", "Computer Engineering"),
        ("Cme", "Computer Engineering"),
        ("CSE", "Computer Engineering"),
        ("Computer", "Computer Engineering"),
        ("ECE", "Electronics & Communication Engineering"),
        ("EC", "Electronics & Communication Engineering"),
        ("Ece", "Electronics & Communication Engineering"),
        ("EEE", "Electrical & Electronics Engineering"),
        ("EE", "Electrical & Electronics Engineering"),
        ("Eee", "Electrical & Electronics Engineering"),
        ("ME", "Mechanical Engineering"),
        ("MEC", "Mechanical Engineering"),
        ("MECH", "Mechanical Engineering"),
        ("Mech", "Mechanical Engineering"),
        ("Mechanical", "Mechanical Engineering"), 
        ("CE", "Civil Engineering"),
        ("CIV", "Civil Engineering"),
        ("CIVIL", "Civil Engineering"),
        ("Civil", "Civil Engineering"),
        ("BS & H", "General"),
        ("BS&H", "General"),
        ("BSH", "General"),
        ("Basic Science", "General"),
        ("General", "General"),
    ];

    let tables = vec!["users", "attendance", "notifications", "subjects", "faculty_subjects"];

    for (short_code, full_name) in updates {
        for table in &tables {
            let query = format!("UPDATE {} SET branch = $1 WHERE branch = $2", table);
            
            let result = sqlx::query(&query)
                .bind(full_name)
                .bind(short_code)
                .execute(pool)
                .await;
                
            match result {
                Ok(r) => {
                    if r.rows_affected() > 0 {
                        println!("Updated {} rows in '{}': {} -> {}", r.rows_affected(), table, short_code, full_name);
                    }
                },
                Err(e) => eprintln!("Failed to update table '{}': {:?}", table, e),
            }
        }
    }
}
