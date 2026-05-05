use axum::{
    routing::{get, post},
    Router,
};
use tower_http::cors::CorsLayer;
use dotenvy::dotenv;

pub mod auth_proto {
    tonic::include_proto!("auth");
}

mod services;
use services::grpc_auth::MyAuthService;
use auth_proto::auth_service_server::AuthServiceServer;

mod models;
use models::AppState;

mod routes;
use routes::*;

mod db;
mod utils;
mod repositories;

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
    
    dotenv().ok();
    
    let pool = db::connection::init_db().await;

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
        .route("/api/issues/:id", axum::routing::delete(issue::delete_issue_handler))
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
        .route("/api/parent/requests/:id", axum::routing::delete(parent::delete_parent_request_handler))
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
        .route("/api/coordinator/overall-syllabus-progress", get(coordinator::get_all_branches_syllabus_progress_handler))
        .route("/api/departments/delete", post(coordinator::delete_department_handler))
        .route("/api/hod/departments", get(hod::get_hod_departments_handler))
        .route("/api/hod/sections", get(hod::get_hod_sections_handler))
        .route("/api/hod/subjects", get(hod::get_hod_subjects_handler))
        .route("/api/hod/course-subjects", post(hod::add_course_subject_handler).get(hod::get_added_course_subjects_handler))
        .route("/api/hod/master-timetable", get(hod::get_master_timetable_handler))
        .route("/api/hod/syllabus/branch-progress", get(hod::get_branch_progress_handler))
        .route("/api/hod/syllabus/year-sections-progress", get(hod::get_year_sections_progress_handler))
        .route("/api/hod/syllabus/section-subjects-progress", get(hod::get_section_subjects_progress_handler))
        .route("/api/incharge/timetable-lookup", get(incharge::incharge_timetable_lookup_handler))
        .route("/api/incharge/update-status", post(incharge::update_class_status_handler))
        .route("/api/incharge/class-status", get(incharge::get_section_class_status_handler))
        .route("/api/hod/daily-activity-report", get(incharge::get_daily_activity_report_handler))
        .route("/api/incharge/branch-daily-detail-report", get(incharge::get_branch_daily_detail_report_handler))
        .route("/api/staff/all", get(hod::get_all_staff_handler))
        .route("/api/hod/faculty-assignment", get(hod::get_faculty_assignment_handler))
        .with_state(AppState { pool })
        .nest_service("/web", tower_http::services::ServeDir::new("static"))
        .fallback(move |req: axum::extract::Request| {
            let mut grpc_service = grpc_service.clone();
            async move {
                let is_grpc = req.headers().get("content-type").map_or(false, |v| v.as_bytes().starts_with(b"application/grpc"));
                
                if is_grpc {
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
                    // Fallback for Web/SPA: Try to serve the static file, else return index.html
                    let path = req.uri().path();
                    
                    // If it's an API route that reached here, it's a real 404
                    if path.starts_with("/api") {
                        return axum::http::Response::builder()
                            .status(axum::http::StatusCode::NOT_FOUND)
                            .body(Body::from("API Route Not Found"))
                            .unwrap();
                    }

                    // Otherwise, serve index.html for Flutter's client-side routing
                    match tokio::fs::read_to_string("static/index.html").await {
                        Ok(content) => axum::http::Response::builder()
                            .header("content-type", "text/html")
                            .status(axum::http::StatusCode::OK)
                            .body(Body::from(content))
                            .unwrap(),
                        Err(_) => axum::http::Response::builder()
                            .status(axum::http::StatusCode::NOT_FOUND)
                            .body(Body::from("Frontend not found. Did you build the web app?"))
                            .unwrap(),
                    }
                }
            }
        })
        .layer(CorsLayer::permissive());

    println!("✅ Server ready");
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn root() -> &'static str {
    "Alwardas Backend Running!"
}

async fn health_check() -> &'static str {
    "OK"
}

