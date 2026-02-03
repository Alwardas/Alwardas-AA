use axum::{
    routing::{get, post},
    Router,
    http::Method,
};
use sqlx::{postgres::{PgPoolOptions, PgConnectOptions}, Pool, Postgres};
use tower_http::cors::{Any, CorsLayer};
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
use axum::extract::Request;
use axum::body::Body;

#[tokio::main]
async fn main() {
    println!("DEBUG: Starting application...");
    let port_str = std::env::var("PORT").unwrap_or_else(|_| "3001".to_string());
    println!("DEBUG: PORT env var is: '{}'", port_str);
    
    // Slight delay to ensure logs are flushed
    tokio::time::sleep(std::time::Duration::from_millis(500)).await;

    let port = port_str.parse::<u16>().expect("Invalid PORT env var");
    
    // Explicit 0.0.0.0 (IPv4) binding
    let addr = std::net::SocketAddr::from(([0, 0, 0, 0], port));

    println!("🚀 Server listening on {} (IPv4)", addr);
    
    // Bind EARLY
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();

    dotenv().ok();
    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");

    let options = PgConnectOptions::from_str(&database_url)
        .expect("Failed to parse DATABASE_URL")
        .statement_cache_capacity(0);

    println!("DEBUG: Connection Options (Host/DB): {}:{}", options.get_host(), options.get_database().unwrap_or("none"));
    println!("DEBUG: Connecting to database...");
    
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .acquire_timeout(std::time::Duration::from_secs(5)) // Reduced timeout
        .connect_with(options.clone())
        .await
        .expect("❌ CRITICAL: Failed to connect to the database. Please check your DATABASE_URL in Railway variables.");

    println!("✅ Successfully connected to the database!");

    // --- MIGRATIONS ---
    println!("DEBUG: Running database migrations...");
    match sqlx::migrate!("./migrations").run(&pool).await {
        Ok(_) => println!("✅ Migrations complete!"),
        Err(e) => {
            eprintln!("⚠️ Migration warning: {}. The app will try to continue.", e);
        }
    }

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

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST, Method::DELETE, Method::PUT])
        .allow_headers(Any);

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
        .route("/api/student/lesson-plan/feedback", post(student::submit_lesson_plan_feedback_handler).get(student::get_lesson_plan_feedback_handler))
        .route("/api/student/lesson-plan/feedback/:id", axum::routing::delete(student::delete_lesson_plan_feedback_handler))
        .route("/api/issues/submit", post(student::submit_issue_handler))
        .route("/api/issues", get(student::get_student_issues_handler))
        .route("/api/user/request-update", post(student::request_profile_update_handler))
        .route("/api/user/request-attendance-correction", post(student::request_attendance_correction_handler))
        .route("/api/user/attendance-correction-requests", get(student::get_attendance_correction_requests_handler))
        .route("/api/user/attendance-correction-requests/delete", post(student::delete_attendance_correction_requests_handler))
        .route("/api/attendance", get(student::get_student_attendance_handler))
        .route("/api/parent/profile", get(parent::get_parent_profile_handler))
        .route("/api/faculty/profile", get(faculty::get_faculty_profile_handler))
        .route("/api/faculty/subjects", get(faculty::get_faculty_subjects_handler))
        .route("/api/faculty/subjects", post(faculty::add_faculty_subject_handler))
        .route("/api/faculty/subjects", axum::routing::delete(faculty::remove_faculty_subject_handler))
        .route("/api/faculty/lesson-plan/complete", post(faculty::mark_lesson_plan_complete_handler))
        .route("/api/faculty/lesson-plan/feedback/reply", post(faculty::reply_to_feedback_handler))
        .route("/api/faculty/by-branch", get(faculty::get_faculty_by_branch_handler))
        .route("/api/students", get(faculty::get_students_handler))
        .route("/api/attendance/submit", post(faculty::submit_attendance_handler))
        .route("/api/attendance/batch", post(faculty::submit_attendance_batch_handler))
        .route("/api/attendance/check", get(faculty::check_attendance_status_handler))
        .route("/api/attendance/class-record", get(faculty::get_class_attendance_record_handler))
        .route("/api/attendance/stats", get(faculty::get_attendance_stats_handler))
        .route("/api/hod/approve", post(faculty::approve_handler))
        .route("/api/hod/approve-subject", post(faculty::approve_subject_handler))
        .route("/api/hod/approve-profile-change", post(faculty::approve_profile_change_handler))
        .route("/api/hod/approve-attendance-correction", post(faculty::approve_attendance_correction_handler))
        .route("/api/timetable", get(faculty::get_timetable_handler))
        .route("/api/timetable/assign", post(faculty::assign_class_handler))
        .route("/api/timetable/clear", post(faculty::clear_class_handler))
        .route("/api/admin/users", get(admin::get_admin_users_handler))
        .route("/api/admin/stats", get(admin::get_admin_stats_handler))
        .route("/api/admin/users/approve", post(admin::admin_approve_user_handler))
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
        .layer(CorsLayer::permissive())
            .layer(axum::middleware::map_request(|req: Request| async move {
                println!("DEBUG: Received request: method={} uri={}", req.method(), req.uri());
                req
            }));

    println!("✅ Server initialization complete. Entering accept loop...");
    axum::serve(listener, app).await.unwrap();
}

async fn root() -> &'static str {
    "Alwardas Backend Running!"
}

async fn health_check() -> &'static str {
    "OK"
}

async fn fix_branch_names(pool: &Pool<Postgres>) {
    println!("DEBUG: Running fix_branch_names migration...");
    
    let updates = vec![
        ("CME", "Computer Engineering"),
        ("CM", "Computer Engineering"),
        ("Cme", "Computer Engineering"),
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
