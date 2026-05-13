use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
    response::IntoResponse,
};
use uuid::Uuid;
use crate::models::{AppState, CreateAnnouncementRequest, GetAnnouncementsQuery};
use serde_json::json;

pub async fn create_announcement_handler(
    State(state): State<AppState>,
    Json(body): Json<CreateAnnouncementRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::management::coordinator_service::create_announcement(&state.pool, body).await {
        Ok(announcement) => {
            println!("CREATE Announcement Result: {:?}", announcement);
            Ok(Json(json!({
                "success": true,
                "message": "Announcement created successfully",
                "data": announcement
            })))
        },
        Err((c, msg)) => {
            println!("CREATE Announcement Error: {:?}", msg);
            Err((c, Json(json!({
                "success": false,
                "message": msg,
                "data": null
            }))))
        },
    }
}

pub async fn get_announcements_handler(
    State(state): State<AppState>,
    Query(params): Query<GetAnnouncementsQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::management::coordinator_service::get_announcements(&state.pool, params).await {
        Ok(announcements) => {
            println!("GET Announcements Result: {:?}", announcements.len());
            Ok(Json(json!({
                "success": true,
                "message": "Announcements fetched successfully",
                "data": announcements
            })))
        },
        Err(_) => {
            println!("GET Announcements Error");
            Err((StatusCode::INTERNAL_SERVER_ERROR, Json(json!({
                "success": false,
                "message": "Failed to fetch announcements",
                "data": null
            }))))
        },
    }
}

pub async fn get_all_departments_handler(
    State(state): State<AppState>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match crate::services::management::coordinator_service::get_all_departments(&state.pool).await {
        Ok(departments) => {
            println!("GET All Departments Result: {:?}", departments.len());
            Ok(Json(json!({
                "success": true,
                "message": "Departments fetched successfully",
                "data": departments
            })))
        },
        Err(_) => {
            println!("GET All Departments Error");
            Err((StatusCode::INTERNAL_SERVER_ERROR, Json(json!({
                "success": false,
                "message": "Failed to fetch departments",
                "data": null
            }))))
        },
    }
}

pub async fn delete_department_handler(
    State(state): State<AppState>,
    Json(payload): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let branch = payload.get("branch").and_then(|v| v.as_str());
    if let Some(branch_name) = branch {
        match crate::services::management::coordinator_service::delete_department(&state.pool, branch_name).await {
            Ok(affected) if affected > 0 => {
                println!("DELETE Department Result: Success");
                Ok(Json(json!({
                    "success": true,
                    "message": "Department deleted successfully",
                    "data": affected
                })))
            },
            Ok(_) => {
                println!("DELETE Department Result: Not Found");
                Err((StatusCode::NOT_FOUND, Json(json!({
                    "success": false,
                    "message": "Department not found",
                    "data": null
                }))))
            },
            Err(_) => {
                println!("DELETE Department Error");
                Err((StatusCode::INTERNAL_SERVER_ERROR, Json(json!({
                    "success": false,
                    "message": "Failed to delete department",
                    "data": null
                }))))
            },
        }
    } else {
        println!("DELETE Department Error: Missing Branch");
        Err((StatusCode::BAD_REQUEST, Json(json!({
            "success": false,
            "message": "Branch name is required",
            "data": null
        }))))
    }
}

pub async fn delete_announcement_handler(
    State(state): State<AppState>,
    Json(payload): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let id_str = payload.get("id").and_then(|v| v.as_str());
    if let Some(id_str) = id_str {
        if let Ok(announcement_id) = Uuid::parse_str(id_str) {
            match crate::services::management::coordinator_service::delete_announcement(&state.pool, announcement_id).await {
                Ok(affected) if affected > 0 => {
                    println!("DELETE Announcement Result: Success");
                    Ok(Json(json!({
                        "success": true,
                        "message": "Announcement deleted successfully",
                        "data": affected
                    })))
                },
                Ok(_) => {
                    println!("DELETE Announcement Result: Not Found");
                    Err((StatusCode::NOT_FOUND, Json(json!({
                        "success": false,
                        "message": "Announcement not found",
                        "data": null
                    }))))
                },
                Err(_) => {
                    println!("DELETE Announcement Error");
                    Err((StatusCode::INTERNAL_SERVER_ERROR, Json(json!({
                        "success": false,
                        "message": "Failed to delete announcement",
                        "data": null
                    }))))
                },
            }
        } else {
            println!("DELETE Announcement Error: Invalid ID Format");
            Err((StatusCode::BAD_REQUEST, Json(json!({
                "success": false,
                "message": "Invalid announcement ID format",
                "data": null
            }))))
        }
    } else {
        println!("DELETE Announcement Error: Missing ID");
        Err((StatusCode::BAD_REQUEST, Json(json!({
            "success": false,
            "message": "Announcement ID is required",
            "data": null
        }))))
    }
}

pub async fn pin_announcement_handler(
    State(state): State<AppState>,
    Json(payload): Json<serde_json::Value>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let id_str = payload.get("id").and_then(|v| v.as_str());
    let is_pinned = payload.get("isPinned").and_then(|v| v.as_bool()).unwrap_or(false);

    if let Some(id_str) = id_str {
        if let Ok(announcement_id) = Uuid::parse_str(id_str) {
            match crate::services::management::coordinator_service::pin_announcement(&state.pool, announcement_id, is_pinned).await {
                Ok(affected) if affected > 0 => {
                    println!("PIN Announcement Result: Success");
                    Ok(Json(json!({
                        "success": true,
                        "message": "Announcement pinned status updated",
                        "data": affected
                    })))
                },
                Ok(_) => {
                    println!("PIN Announcement Result: Not Found");
                    Err((StatusCode::NOT_FOUND, Json(json!({
                        "success": false,
                        "message": "Announcement not found",
                        "data": null
                    }))))
                },
                Err(_) => {
                    println!("PIN Announcement Error");
                    Err((StatusCode::INTERNAL_SERVER_ERROR, Json(json!({
                        "success": false,
                        "message": "Failed to update pin status",
                        "data": null
                    }))))
                },
            }
        } else {
            println!("PIN Announcement Error: Invalid ID Format");
            Err((StatusCode::BAD_REQUEST, Json(json!({
                "success": false,
                "message": "Invalid announcement ID format",
                "data": null
            }))))
        }
    } else {
        println!("PIN Announcement Error: Missing ID");
        Err((StatusCode::BAD_REQUEST, Json(json!({
            "success": false,
            "message": "Announcement ID is required",
            "data": null
        }))))
    }
}

pub async fn get_all_branches_syllabus_progress_handler(
    State(state): State<AppState>,
    Query(params): Query<serde_json::Value>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let course_id = params.get("courseId").and_then(|v| v.as_str()).unwrap_or("C-23");
    match crate::services::management::coordinator_service::get_all_branches_syllabus_progress(&state.pool, course_id).await {
        Ok(res) => {
            println!("GET All Progress Result: Success");
            Ok(Json(json!({
                "success": true,
                "message": "Progress fetched successfully",
                "data": res
            })))
        },
        Err(_) => {
            println!("GET All Progress Error");
            Err((StatusCode::INTERNAL_SERVER_ERROR, Json(json!({
                "success": false,
                "message": "Failed to fetch progress",
                "data": null
            }))))
        },
    }
}
