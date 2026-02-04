pub mod admin;
pub mod faculty;
pub mod student;
pub mod parent;
pub mod principal;
pub mod coordinator;

use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
use sqlx::{Postgres, Row};
use crate::models::*;
use uuid::Uuid;
use chrono::{Utc, Datelike};

// --- Auth Handlers ---

pub async fn signup_handler(
    State(state): State<AppState>,
    Json(payload): Json<SignupRequest>,
) -> Result<Json<AuthResponse>, (StatusCode, Json<AuthResponse>)> {
    
    // Auto-approval logic
    let is_approved = match payload.role.as_str() {
        "Admin" => true,
        _ => false, // Principal, Student, Faculty, HOD need approval
    };

    // Auto-Calculate Branch, Year, Semester, and Batch for Students based on Login ID
    let (final_branch, final_year, final_semester, final_batch) = if payload.role == "Student" {
        let parts: Vec<&str> = payload.login_id.split('-').collect();
        if parts.len() >= 2 {
            let year_prefix = &parts[0].chars().take(2).collect::<String>();
            // Attempt to parse year
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

    let existing_user = sqlx::query("SELECT id FROM users WHERE login_id = $1")
        .bind(&payload.login_id)
        .fetch_optional(&state.pool)
        .await
        .unwrap_or(None);

    let row = if let Some(existing) = existing_user {
        // UPDATE existing account (Merge/Claim)
        let uid: Uuid = existing.get("id");
        
        sqlx::query(
            "UPDATE users SET 
                full_name = $1, 
                password_hash = $2, 
                branch = $3, 
                year = $4, 
                phone_number = $5, 
                dob = $6::DATE, 
                is_approved = $7, 
                experience = $8, 
                email = $9,
                semester = $10, 
                batch_no = $11
             WHERE id = $12 
             RETURNING id"
        )
        .bind(&payload.full_name)
        .bind(&payload.password)
        .bind(&final_branch)
        .bind(&final_year)
        .bind(&payload.phone_number)
        .bind(&payload.dob)
        .bind(is_approved)
        .bind(&payload.experience)
        .bind(&payload.email)
        .bind(&final_semester)
        .bind(&final_batch)
        .bind(uid)
        .fetch_one(&state.pool)
        .await
    } else {
        // INSERT New User
        sqlx::query(
            "INSERT INTO users (full_name, role, login_id, password_hash, branch, year, phone_number, dob, is_approved, experience, email, semester, batch_no) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8::DATE, $9, $10, $11, $12, $13) 
             RETURNING id"
        )
        .bind(&payload.full_name)
        .bind(&payload.role)
        .bind(&payload.login_id)
        .bind(&payload.password)
        .bind(&final_branch) 
        .bind(&final_year)   
        .bind(&payload.phone_number)
        .bind(&payload.dob)
        .bind(is_approved)
        .bind(&payload.experience)
        .bind(&payload.email)
        .bind(&final_semester)
        .bind(&final_batch)
        .fetch_one(&state.pool)
        .await
    };

    match row {
        Ok(r) => {
            let user_id = r.get::<Uuid, _>("id");
            
            // Create notification for HOD if approval is needed
            if !is_approved {
                let msg = format!("New {} signup request: {} ({})", payload.role, payload.full_name, payload.login_id);
                let query_builder = sqlx::query(
                    "INSERT INTO notifications (type, message, sender_id, branch, status, recipient_id) VALUES ($1, $2, $3, $4, $5, $6)"
                )
                .bind("USER_APPROVAL")
                .bind(msg)
                .bind(&payload.login_id);

                let query = if payload.role == "Student" || payload.role == "Faculty" || payload.role == "Parent" {
                    // Send to HOD of that branch
                    query_builder.bind(&payload.branch).bind("UNREAD").bind(Some("HOD_RECIPIENT"))
                } else if payload.role == "HOD" {
                    // Send to Principal
                    query_builder.bind(None::<String>).bind("UNREAD").bind(Some("PRINCIPAL_RECIPIENT"))
                } else if payload.role == "Principal" {
                    // Send to Coordinator
                    query_builder.bind(None::<String>).bind("UNREAD").bind(Some("COORDINATOR_RECIPIENT"))
                } else if payload.role == "Coordinator" {
                    // Send to Admin
                    query_builder.bind(None::<String>).bind("UNREAD").bind(Some("ADMIN_RECIPIENT"))
                } else {
                    query_builder.bind(None::<String>).bind("UNREAD").bind(None::<String>)
                };
                
                query.execute(&state.pool).await.ok();
            }

            let msg = if is_approved {
                "Account created and activated!".to_string()
            } else {
                "Account created! Waiting for approval.".to_string()
            };
            Ok(Json(AuthResponse { 
                id: Some(user_id.to_string()),
                message: msg, 
                role: Some(payload.role), 
                full_name: Some(payload.full_name),
                login_id: Some(payload.login_id),
                branch: payload.branch,
                year: payload.year,
                semester: final_semester,
                batch_no: final_batch
            }))
        },
        Err(e) => {
            eprintln!("Signup Error: {:?}", e);
            Err((StatusCode::INTERNAL_SERVER_ERROR, Json(AuthResponse { 
                id: None,
                message: "User likely already exists".to_string(), 
                role: None, 
                full_name: None,
                login_id: None,
                branch: None,
                year: None,
                semester: None,
                batch_no: None
            })))
        }
    }
}

pub async fn login_handler(
    State(state): State<AppState>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<AuthResponse>, (StatusCode, Json<AuthResponse>)> {

    #[derive(sqlx::FromRow)]
    struct UserRow {
        id: uuid::Uuid,
        full_name: String,
        role: String,
        password_hash: String,
        is_approved: Option<bool>,
        login_id: String,
        branch: Option<String>,
        year: Option<String>,
        semester: Option<String>,
        batch_no: Option<String>,
    }

    let user_result: Option<UserRow> = sqlx::query_as(
        "SELECT id, full_name, role, password_hash, is_approved, login_id, branch, year, semester, batch_no FROM users WHERE login_id = $1"
    )
    .bind(&payload.login_id)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    if let Some(user) = user_result {
        if user.password_hash == payload.password {
             if !user.is_approved.unwrap_or(false) {
                 return Err((StatusCode::FORBIDDEN, Json(AuthResponse { 
                     id: None,
                     message: "Account pending approval".to_string(), 
                     role: None, 
                     full_name: None,
                     login_id: None,
                     branch: None,
                     year: None,
                     semester: None,
                     batch_no: None
                 })));
             }
             return Ok(Json(AuthResponse { 
                 id: Some(user.id.to_string()),
                 message: "Login Successful".to_string(), 
                 role: Some(user.role),
                 full_name: Some(user.full_name),
                 login_id: Some(user.login_id),
                 branch: user.branch,
                 year: user.year,
                 semester: user.semester,
                 batch_no: user.batch_no,
             }));
        }
    }

    Err((StatusCode::UNAUTHORIZED, Json(AuthResponse { 
        id: None,
        message: "Invalid ID or Password".to_string(), 
        role: None, 
        full_name: None,
        login_id: None,
        branch: None,
        year: None,
        semester: None,
        batch_no: None
    })))
}

pub async fn check_user_existence_handler(
    State(state): State<AppState>,
    Query(params): Query<CheckUserQuery>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    
    let row: Option<(String, Option<String>, Option<String>, Option<String>, Option<String>, Option<chrono::NaiveDate>, Option<String>)> = 
        sqlx::query_as("SELECT full_name, branch, year, phone_number, email, dob, role FROM users WHERE login_id = $1")
        .bind(&params.login_id)
        .fetch_optional(&state.pool)
        .await
        .unwrap_or(None);

    match row {
        Some((full_name, branch, year, phone, email, dob, role)) => Ok(Json(serde_json::json!({
            "exists": true,
            "fullName": full_name,
            "branch": branch,
            "year": year,
            "phone": phone,
            "email": email,
            "dob": dob,
            "role": role
        }))),
        None => Ok(Json(serde_json::json!({
            "exists": false,
            "fullName": null
        })))
    }
}

pub async fn forgot_password_handler(
    State(state): State<AppState>,
    Json(payload): Json<ForgotPasswordRequest>,
) -> Result<Json<ResetResponse>, (StatusCode, Json<ResetResponse>)> {
    
    #[derive(sqlx::FromRow)]
    struct UserCheck {
        role: String,
    }
    
    let user_res: Option<UserCheck> = sqlx::query_as(
        "SELECT role FROM users WHERE login_id = $1 AND dob = $2::DATE"
    )
    .bind(&payload.login_id)
    .bind(&payload.dob)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    if let Some(user) = user_res {
        let (msg, action) = match user.role.as_str() {
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

        return Ok(Json(ResetResponse {
            message: msg.to_string(),
            action: action.to_string(),
        }));
    }

    Err((StatusCode::NOT_FOUND, Json(ResetResponse { 
        message: "No user found with this ID and Date of Birth.".to_string(), 
        action: "error".to_string() 
    })))
}

pub async fn change_password_handler(
    State(state): State<AppState>,
    Json(payload): Json<ChangePasswordRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let user_id_uuid = Uuid::parse_str(&payload.user_id).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid User ID"}))))?;

    if let Some(old) = &payload.old_password {
         if !old.is_empty() {
             let current_pass: String = sqlx::query_scalar("SELECT password_hash FROM users WHERE id = $1")
                .bind(user_id_uuid)
                .fetch_one(&state.pool)
                .await
                .map_err(|_| (StatusCode::NOT_FOUND, Json(serde_json::json!({"error": "User not found"}))))?;
                
             if current_pass != *old {
                 return Err((StatusCode::UNAUTHORIZED, Json(serde_json::json!({"error": "Incorrect old password"}))));
             }
         }
    }

    sqlx::query("UPDATE users SET password_hash = $1 WHERE id = $2")
        .bind(&payload.new_password)
        .bind(user_id_uuid)
        .execute(&state.pool)
        .await
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to update"}))))?;

    Ok(StatusCode::OK)
}

pub async fn update_user_handler(
    State(state): State<AppState>,
    Json(payload): Json<UpdateUserRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let user_id_uuid = Uuid::parse_str(&payload.user_id).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid User ID"}))))?;

    sqlx::query(
        "UPDATE users SET 
            full_name = COALESCE($1, full_name), 
            phone_number = COALESCE($2, phone_number), 
            email = COALESCE($3, email), 
            experience = COALESCE($4, experience), 
            dob = COALESCE($5::DATE, dob),
            branch = COALESCE($6, branch),
            year = COALESCE($7, year),
            semester = COALESCE($8, semester),
            batch_no = COALESCE($9, batch_no),
            login_id = COALESCE($10, login_id)
         WHERE id = $11"
    )
    .bind(&payload.full_name)
    .bind(&payload.phone_number)
    .bind(&payload.email)
    .bind(&payload.experience)
    .bind(&payload.dob)
    .bind(&payload.branch)
    .bind(&payload.year)
    .bind(&payload.semester)
    .bind(&payload.batch_no)
    .bind(&payload.login_id)
    .bind(user_id_uuid)
    .execute(&state.pool)
    .await
    .map_err(|e| {
            eprintln!("Update Error: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to update profile"})))
    })?;

    Ok(StatusCode::OK)
}

pub async fn get_notifications_handler(
    State(state): State<AppState>,
    Query(params): Query<NotificationQuery>,
) -> Result<Json<Vec<Notification>>, StatusCode> {
    println!("DEBUG: Fetch notifications for role={:?} branch={:?} user_id={:?}", params.role, params.branch, params.user_id);
    
    let mut query = "SELECT id, type, message, sender_id, recipient_id, branch, status, created_at FROM notifications".to_string();
    let mut conditions = Vec::new();

    if let Some(role) = &params.role {
        match role.as_str() {
            "Student" => {
                 if let Some(uid) = &params.user_id {
                    conditions.push(format!("recipient_id = '{}'", uid));
                 }
            },
            "Faculty" => {
                if let Some(uid) = &params.user_id {
                    conditions.push(format!("(recipient_id = '{}' OR (recipient_id IS NULL AND (branch = '{}' OR branch IS NULL)))", 
                        uid, params.branch.as_deref().unwrap_or("")));
                }
            },
            "HOD" => {
                if let Some(branch) = &params.branch {
                    conditions.push(format!("(recipient_id = 'HOD_RECIPIENT' AND branch = '{}') OR (recipient_id IS NULL AND (branch = '{}' OR branch IS NULL))", branch, branch));
                } else if let Some(uid) = &params.user_id {
                     conditions.push(format!("recipient_id = '{}'", uid));
                }
            },
            "Principal" => {
                conditions.push("(recipient_id = 'PRINCIPAL_RECIPIENT' OR (recipient_id IS NULL AND branch IS NULL))".to_string());
            },
            "Coordinator" => {
                conditions.push("(recipient_id = 'COORDINATOR_RECIPIENT' OR (recipient_id IS NULL AND branch IS NULL))".to_string());
            },
            "Admin" => {
                conditions.push("(recipient_id = 'ADMIN_RECIPIENT' OR recipient_id IS NULL)".to_string());
            },
            _ => {
                if let Some(uid) = &params.user_id {
                    conditions.push(format!("(recipient_id = '{}' OR (recipient_id IS NULL AND (branch = '{}' OR branch IS NULL)))", 
                        uid, params.branch.as_deref().unwrap_or("")));
                }
            }
        }
    } else if let Some(uid) = &params.user_id {
        conditions.push(format!("recipient_id = '{}'", uid));
    }

    if !conditions.is_empty() {
        query.push_str(" WHERE ");
        query.push_str(&conditions.join(" AND "));
    }
    
    query.push_str(" ORDER BY created_at DESC");

    let notifications = sqlx::query_as::<Postgres, Notification>(&query)
        .fetch_all(&state.pool)
        .await
        .map_err(|e| {
            println!("Get Notifications Error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    Ok(Json(notifications))
}

pub async fn delete_notifications_handler(
    State(state): State<AppState>,
    Json(payload): Json<DeleteNotificationsRequest>,
) -> Result<StatusCode, StatusCode> {
    sqlx::query("DELETE FROM notifications WHERE id = ANY($1)")
        .bind(&payload.ids)
        .execute(&state.pool)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    Ok(StatusCode::OK)
}
