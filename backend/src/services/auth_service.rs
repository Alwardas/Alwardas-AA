use sqlx::{PgPool};
use axum::{Json, http::StatusCode};
use crate::models::{LoginRequest, AuthResponse, SignupRequest, ProfileQuery, CheckUserQuery, ForgotPasswordRequest, ResetResponse, ChangePasswordRequest, UpdateUserRequest};
use uuid::Uuid;
use chrono::{Utc, Datelike};
use crate::repositories::auth;

pub async fn login_user(
    pool: &PgPool,
    payload: LoginRequest,
) -> Result<AuthResponse, (StatusCode, Json<AuthResponse>)> {
    let normalized_id = payload.login_id.trim().to_lowercase();
    println!("DEBUG: Login attempt for ID: {}", normalized_id);

    let user_result = auth::find_user_by_login_id(pool, &normalized_id)
        .await
        .map_err(|e| {
            eprintln!("Login DB Error for {}: {:?}", normalized_id, e);
            (StatusCode::INTERNAL_SERVER_ERROR, Json(AuthResponse { 
                id: None, message: format!("Database Error: {}", e), role: None, full_name: None, login_id: None, branch: None, year: None, semester: None, batch_no: None, section: None
            }))
        })?;

    if let Some(user) = user_result {
        if user.password_hash.trim() == payload.password.trim() {
             if !user.is_approved.unwrap_or(false) {
                 return Err((StatusCode::FORBIDDEN, Json(AuthResponse { 
                     id: None, message: "Account pending approval".to_string(), role: None, full_name: None, login_id: None, branch: None, year: None, semester: None, batch_no: None, section: None
                 })));
             }
             return Ok(AuthResponse { 
                 id: Some(user.id.to_string()), message: "Login Successful".to_string(), role: Some(user.role), full_name: Some(user.full_name), login_id: Some(user.login_id), branch: user.branch, year: user.year, semester: user.semester, batch_no: user.batch_no, section: user.section,
             });
        }
    }

    Err((StatusCode::UNAUTHORIZED, Json(AuthResponse { 
        id: None, message: "Invalid ID or Password".to_string(), role: None, full_name: None, login_id: None, branch: None, year: None, semester: None, batch_no: None, section: None
    })))
}

fn normalize_branch(code: &str) -> String {
    match code.to_uppercase().as_str() {
        "CME" | "CM" | "CSE" | "COMPUTER" => "Computer Engineering".to_string(),
        "ECE" | "EC" => "Electronics & Communication Engineering".to_string(),
        "EEE" | "EE" => "Electrical & Electronics Engineering".to_string(),
        "ME" | "MEC" | "MECH" | "MECHANICAL" => "Mechanical Engineering".to_string(),
        "CE" | "CIV" | "CIVIL" => "Civil Engineering".to_string(),
        "BS & H" | "BS&H" | "BSH" | "BASIC SCIENCE" | "GENERAL" => "General".to_string(),
        _ => code.to_string(),
    }
}

pub async fn signup_user(
    pool: &PgPool,
    payload: SignupRequest,
) -> Result<AuthResponse, (StatusCode, Json<AuthResponse>)> {
    
    let is_approved = match payload.role.as_str() {
        "Admin" => true,
        "Student" => true,
        _ => false,
    };
    
    let section = payload.section.clone().unwrap_or_else(|| "Section A".to_string());

    let (final_branch, final_year, final_semester, final_batch) = if payload.role == "Student" {
        let parts: Vec<&str> = payload.login_id.split('-').collect();
        if parts.len() >= 2 {
            let year_prefix = &parts[0].chars().take(2).collect::<String>();
            let (derived_year, derived_batch) = if let Ok(yy) = year_prefix.parse::<i32>() {
                let joining_year = 2000 + yy;
                let batch_str = format!("{}-{}", joining_year, joining_year + 3);
                
                let now = Utc::now();
                let current_year = now.year();
                let current_month = now.month(); 
                
                let academic_year_start = if current_month < 6 { current_year - 1 } else { current_year };
                let diff = academic_year_start - joining_year;

                match diff {
                    0 => (Some("1st Year".to_string()), Some(batch_str)),
                    1 => (Some("2nd Year".to_string()), Some(batch_str)),
                    2 => (Some("3rd Year".to_string()), Some(batch_str)), 
                    _ => (Some("Graduated".to_string()), Some(batch_str))
                }
            } else {
                (payload.year.clone(), None)
            };

            let derived_semester = if let Some(y) = &derived_year {
                 let now = Utc::now();
                 let is_even_sem = now.month() < 6; 
                 match y.as_str() {
                     "1st Year" => Some("1st Year".to_string()),
                     "2nd Year" => Some(if is_even_sem { "4th Semester".to_string() } else { "3rd Semester".to_string() }),
                     "3rd Year" => Some(if is_even_sem { "6th Semester".to_string() } else { "5th Semester".to_string() }),
                     _ => None
                 }
            } else {
                None
            };

            let branch_code = parts[1];
            let derived_branch = Some(normalize_branch(branch_code));

            (derived_branch, derived_year, derived_semester, derived_batch)
        } else {
            (payload.branch.clone(), payload.year.clone(), None, None)
        }
    } else {
        (payload.branch.clone(), payload.year.clone(), None, None)
    };

    let existing_user_id = auth::find_user_id_by_login_id(pool, &payload.login_id).await.unwrap_or(None);

    if let Some(user_id) = existing_user_id {
        let new_data = serde_json::to_value(&payload).unwrap();

        auth::delete_pending_profile_updates(pool, user_id).await.ok();
        let insert_res = auth::insert_profile_update_request(pool, user_id, new_data).await;

        match insert_res {
            Ok(_) => {
                return Ok(AuthResponse { 
                    id: Some(user_id.to_string()),
                    message: "Update request submitted. Please login with your CURRENT credentials to approve changes.".to_string(), 
                    role: Some(payload.role), 
                    full_name: Some(payload.full_name),
                    login_id: Some(payload.login_id),
                    branch: payload.branch,
                    year: payload.year,
                    semester: final_semester,
                    batch_no: final_batch,
                    section: Some(section.clone())
                });
            },
            Err(e) => {
                 eprintln!("Signup Update Request Error: {:?}", e);
                 return Err((StatusCode::INTERNAL_SERVER_ERROR, Json(AuthResponse { 
                    id: None, message: "Failed to submit update request".to_string(), branch: None, year: None, semester: None, batch_no: None, section: None, full_name: None, login_id: None, role: None
                 })));
            }
        }
    }

    let mut target_student_id = String::new();
    if payload.role == "Parent" {
        target_student_id = payload.login_id.strip_prefix("P-").unwrap_or(&payload.login_id).to_string();
        
        let student_exists = auth::find_user_by_login_id_and_role(pool, &target_student_id, "Student").await.unwrap_or(None);
            
        if student_exists.is_none() {
            return Err((StatusCode::BAD_REQUEST, Json(AuthResponse { 
                id: None, message: format!("Student ID {} not found. Cannot link Parent account.", target_student_id), role: None, full_name: None, login_id: None, branch: None, year: None, semester: None, batch_no: None, section: None
            })));
        }
    }

    let row = auth::insert_user(
        pool, &payload, final_branch.as_deref(), final_year.as_deref(), final_semester.as_deref(), final_batch.as_deref(), &section, is_approved
    ).await;

    match row {
        Ok(user_id) => {
            if !is_approved {
                let msg = format!("New {} signup request: {} ({})", payload.role, payload.full_name, payload.login_id);
                
                let (branch, recipient) = if payload.role == "Student" || payload.role == "Faculty" || payload.role == "Parent" {
                    (payload.branch.clone(), Some("HOD_RECIPIENT"))
                } else if payload.role == "HOD" {
                    (None, Some("PRINCIPAL_RECIPIENT"))
                } else if payload.role == "Principal" {
                    (None, Some("COORDINATOR_RECIPIENT"))
                } else if payload.role == "Coordinator" || payload.role == "Incharge" {
                    (None, Some("PRINCIPAL_RECIPIENT"))
                } else {
                    (None, None)
                };
                
                auth::insert_notification(pool, "USER_APPROVAL", msg, &payload.login_id, branch.as_deref(), recipient).await.ok();
            }

            let msg = if is_approved {
                "Account created and activated!".to_string()
            } else {
                "Account created! Waiting for approval.".to_string()
            };
            
            if payload.role == "Parent" && !target_student_id.is_empty() {
                auth::insert_parent_student_link(pool, &payload.login_id, &target_student_id).await.ok();
            }
            
            Ok(AuthResponse { 
                id: Some(user_id.to_string()), message: msg, role: Some(payload.role), full_name: Some(payload.full_name), login_id: Some(payload.login_id), branch: payload.branch, year: payload.year, semester: final_semester, batch_no: final_batch, section: Some(section.clone())
            })
        },
        Err(e) => {
            eprintln!("Signup Error: {:?}", e);
            Err((StatusCode::INTERNAL_SERVER_ERROR, Json(AuthResponse { 
                id: None, message: format!("User likely already exists: {}", e), role: None, full_name: None, login_id: None, branch: None, year: None, semester: None, batch_no: None, section: None
            })))
        }
    }
}

pub async fn reject_my_pending_update(
    pool: &PgPool,
    payload: serde_json::Value,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let user_id_str = payload.get("userId").and_then(|v| v.as_str()).unwrap_or("");
    let user_id = Uuid::parse_str(user_id_str).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid User ID"}))))?;

    auth::delete_auth_notifications(pool, user_id_str, "PROFILE_UPDATE_REQUEST").await.ok();
    auth::delete_pending_updates(pool, user_id, vec!["PENDING_USER_APPROVAL", "PENDING"]).await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "DB Delete Error"}))))?;

    Ok(StatusCode::OK)
}

pub async fn check_my_pending_update(
    pool: &PgPool,
    params: ProfileQuery,
) -> Result<serde_json::Value, StatusCode> {
    let user_uuid = if let Ok(u) = Uuid::parse_str(&params.user_id) {
        u
    } else {
        auth::find_user_id_by_login_id(pool, &params.user_id)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
            .ok_or(StatusCode::BAD_REQUEST)?
    };

    let row = auth::find_pending_user_update(pool, user_uuid).await.unwrap_or(None);

    if let Some((request_id, data)) = row {
       Ok(serde_json::json!({ "exists": true, "requestId": request_id, "data": data }))
    } else {
       Ok(serde_json::json!({ "exists": false }))
    }
}

pub async fn accept_my_pending_update(
    pool: &PgPool,
    payload: serde_json::Value,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let user_id_str = payload.get("userId").and_then(|v| v.as_str()).unwrap_or("");
    let user_id = Uuid::parse_str(user_id_str).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid User ID"}))))?;

     let (request_id, new_data) = auth::find_pending_user_update(pool, user_id)
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "DB Error"}))))?
        .ok_or((StatusCode::NOT_FOUND, Json(serde_json::json!({"error": "No pending request"}))))?;

    let signup_data: SignupRequest = serde_json::from_value(new_data.clone())
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Invalid Data format"}))))?;

    let section = signup_data.section.clone().unwrap_or_else(|| "Section A".to_string());
    
    auth::update_user_from_signup(pool, user_id, &signup_data, &section)
        .await
        .map_err(|e| {
             eprintln!("Accept Update Error: {:?}", e);
             (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Update Failed"})))
        })?;

    auth::delete_profile_update_request(pool, request_id).await.ok();

    Ok(StatusCode::OK)
}

pub async fn check_user_existence(
    pool: &PgPool,
    params: CheckUserQuery,
) -> Result<serde_json::Value, StatusCode> {
    auth::find_user_info_for_check(pool, &params.login_id)
        .await
        .map(|res| res.unwrap_or(serde_json::json!({"exists": false, "fullName": null})))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn forgot_password(
    pool: &PgPool,
    payload: ForgotPasswordRequest,
) -> Result<ResetResponse, (StatusCode, Json<ResetResponse>)> {
    let role_opt = auth::find_user_role_by_id_and_dob(pool, &payload.login_id, &payload.dob)
        .await
        .unwrap_or(None);

    if let Some(role) = role_opt {
        let (msg, action) = match role.as_str() {
            "Student" | "Parent" | "Faculty" => (
                "Request sent to HOD. You will be notified upon approval.", 
                "request_sent"
            ),
            "HOD" => (
                "Request sent to Principal. Please wait for approval.", 
                "request_sent"
            ),
            "Principal" => (
                "OTP sent to your registered Email.", 
                "otp_sent"
            ),
            "Admin" => (
                "Admins cannot reset passwords via this form. Contact DB Admin.", 
                "admin_contact"
            ),
            _ => ("Unknown Role.", "error"),
        };

        return Ok(ResetResponse {
            message: msg.to_string(),
            action: action.to_string(),
        });
    }

    Err((StatusCode::NOT_FOUND, Json(ResetResponse { 
        message: "No user found with this ID and Date of Birth.".to_string(), 
        action: "error".to_string() 
    })))
}

pub async fn change_password(
    pool: &PgPool,
    payload: ChangePasswordRequest,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let user_id_uuid = Uuid::parse_str(&payload.user_id).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid User ID"}))))?;

    if let Some(old) = &payload.old_password {
         if !old.is_empty() {
             let current_pass = auth::find_password_hash_by_id(pool, user_id_uuid)
                .await
                .map_err(|_| (StatusCode::NOT_FOUND, Json(serde_json::json!({"error": "User not found"}))))?;
                
             if current_pass != *old {
                 return Err((StatusCode::UNAUTHORIZED, Json(serde_json::json!({"error": "Incorrect old password"}))));
             }
         }
    }

    auth::update_password(pool, user_id_uuid, &payload.new_password)
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to update"}))))?;

    Ok(StatusCode::OK)
}

pub async fn update_user(
    pool: &PgPool,
    payload: UpdateUserRequest,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    auth::update_user_fields(pool, &payload)
        .await
        .map_err(|e| {
            eprintln!("Update Error: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to update profile"})))
        })?;

    Ok(StatusCode::OK)
}
